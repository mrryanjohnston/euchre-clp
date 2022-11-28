package main

import (
	"fmt"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/gorilla/sessions"
	"github.com/gorilla/websocket"
	"log"
	"net/http"
	"unsafe"
)

/*
#cgo CFLAGS: -std=c99 -O3 -fno-strict-aliasing -Wno-unused-result
#cgo LDFLAGS: -lm
#include "clips.h"
typedef const char cchar_t;
bool QueryWsCallback(Environment *,cchar_t *,void *);
void WriteWsCallback(Environment *,cchar_t *,cchar_t *,void *);
int ReadWsCallback(Environment *,cchar_t *,void *);
int UnreadWsCallback(Environment *,cchar_t *,int,void *);
void NewUuid(Environment *, UDFContext *, UDFValue *);
*/
import "C"

//export NewUuid
func NewUuid(env *C.Environment, _ *C.UDFContext, out *C.UDFValue) {
	c_newUuid := C.CString(uuid.NewString())
	defer C.free(unsafe.Pointer(c_newUuid))
	*(**C.CLIPSLexeme)(unsafe.Pointer(&out.anon0[0])) = C.CreateSymbol(env, c_newUuid)
}

type websocketConnection struct {
	sid string
	id  string
	c   *websocket.Conn
	b   []byte
	bc  chan []byte
}

var websocketConnections = make(chan *websocketConnection)
var websocketDisconnections = make(chan string)
var websocketMessageBufferedChannel = make(chan string)
var store = sessions.NewCookieStore([]byte("euchre"))
var upgrader = websocket.Upgrader{}

func Websocket(w http.ResponseWriter, r *http.Request) {
	s, err := store.Get(r, "euchre-session")
	if err != nil {
		log.Print("ERROR: session decode failed:", err)
		return
	}
	if s.Values["ID"] == nil {
		s.Values["ID"] = uuid.NewString()
		err := s.Save(r, w)
		if err != nil {
			log.Print("ERROR: saving session failed:", err)
			return
		}
		log.Print("INFO: generated new id for session: ", s.Values["ID"])
	}
	sid := s.Values["ID"].(string)

	c, err := upgrader.Upgrade(w, r, w.Header())
	if err != nil {
		log.Println("ERROR: upgrade failed:", err)
		return
	}
	defer c.Close()

	id := uuid.NewString()
	websocketReadChannel := make(chan []byte)
	websocketConnections <- &websocketConnection{sid, id, c, []byte{}, websocketReadChannel}

	for {
		_, message, err := c.ReadMessage()
		if err != nil {
			log.Println("INFO: error reading message:", err)
			websocketDisconnections <- id
			break
		}
		websocketMessageBufferedChannel <- id
		websocketReadChannel <- append(message, byte('\n'))
	}
}

//export QueryWsCallback
func QueryWsCallback(e *C.Environment, logicalName *C.cchar_t, _ unsafe.Pointer) C.bool {
	_, ok := websockets[C.GoString(logicalName)]
	return C.bool(ok)
}

//export WriteWsCallback
func WriteWsCallback(e *C.Environment, logicalName *C.cchar_t, str *C.cchar_t, context unsafe.Pointer) {
	if err := websockets[C.GoString(logicalName)].c.WriteMessage(1, []byte(C.GoString(str))); err != nil {
		log.Printf("WARNING: attempting to send message to socket %s errored: %s", C.GoString(logicalName), err)
	}
}

//export ReadWsCallback
func ReadWsCallback(e *C.Environment, logicalName *C.cchar_t, context unsafe.Pointer) C.int {
	id := C.GoString(logicalName)
	websocket := websockets[id]
	if len(websocket.b) == 0 {
		websocket.b = append(websocket.b, <-websocket.bc...)
	}
	ch := websocket.b[0]
	websocket.b = websocket.b[1:]
	return C.int(ch)
}

//export UnreadWsCallback
func UnreadWsCallback(e *C.Environment, logicalName *C.cchar_t, ch C.int, context unsafe.Pointer) C.int {
	id := C.GoString(logicalName)
	websockets[id].b = append([]byte{byte(ch)}, websockets[id].b...)
	return C.int(ch)
}

var websockets = make(map[string]*websocketConnection)

func main() {
	env := C.CreateEnvironment()
	c_newUuid := C.CString("new-uuid")
	defer C.free(unsafe.Pointer(c_newUuid))
	c_NewUuid := C.CString("NewUuid")
	defer C.free(unsafe.Pointer(c_NewUuid))
	c_y := C.CString("y")
	defer C.free(unsafe.Pointer(c_y))
	C.AddUDF(env, c_newUuid, c_y, C.ushort(0), C.ushort(0), nil, (*C.UserDefinedFunction)(unsafe.Pointer(C.NewUuid)), c_NewUuid, nil)
	defer C.DestroyEnvironment(env)
	c_f := C.CString("euchre.bat")
	defer C.free(unsafe.Pointer(c_f))
	C.BatchStar(env, c_f)

	go func(env *C.Environment) {
		for {
			select {
			case id := <-websocketMessageBufferedChannel:
				fact_c := C.CString(fmt.Sprintf("(received-message-from %s)", id))
				C.AssertString(env, fact_c)
				C.free(unsafe.Pointer(fact_c))
			case websocketConnection := <-websocketConnections:
				websockets[websocketConnection.id] = websocketConnection
				fact_c := C.CString(fmt.Sprintf("(connection %s %s)", websocketConnection.sid, websocketConnection.id))
				C.AssertString(env, fact_c)
				C.free(unsafe.Pointer(fact_c))
				id_c := C.CString(websocketConnection.id)
				C.AddRouter(
					env, id_c, 20,
					(*C.RouterQueryFunction)((unsafe.Pointer)(C.QueryWsCallback)),
					(*C.RouterWriteFunction)((unsafe.Pointer)(C.WriteWsCallback)),
					(*C.RouterReadFunction)((unsafe.Pointer)(C.ReadWsCallback)),
					(*C.RouterUnreadFunction)((unsafe.Pointer)(C.UnreadWsCallback)),
					nil, nil)
				C.free(unsafe.Pointer(id_c))
			case id := <-websocketDisconnections:
				fact_c := C.CString(fmt.Sprintf("(disconnection %s)", id))
				C.AssertString(env, fact_c)
				C.free(unsafe.Pointer(fact_c))
			}
			C.Run(env, -1)
		}
	}(env)

	r := mux.NewRouter()
	r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./index.html")
	})
	r.HandleFunc("/websocket", Websocket)
	log.Println("Listening on port 8080...")
	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
