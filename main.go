package main

import (
	"flag"
	"fmt"
	"github.com/google/uuid"
	"github.com/gorilla/sessions"
	"github.com/gorilla/websocket"
	"log"
	"net/http"
	"unsafe"
)

/*
#cgo CFLAGS: -std=c99 -O3 -fno-strict-aliasing
#cgo LDFLAGS: -lm
#include "clips.h"
#include "util.h"
typedef const char cchar_t;

bool QueryWsCallback(Environment *,cchar_t *,void *);
void WriteWsCallback(Environment *,cchar_t *,cchar_t *,void *);
int ReadWsCallback(Environment *,cchar_t *,void *);
int UnreadWsCallback(Environment *,cchar_t *,int,void *);
void ExitWsCallback(Environment *environment,int,void *);
*/
import "C"

var addr = flag.String("addr", "0.0.0.0:8765", "websocket address")
var upgrader = websocket.Upgrader{}
var store = sessions.NewCookieStore([]byte("euchre-development"))
var websockets = make(map[string]*Conn)
var websocketMessageBufferedChannel = make(chan string)
var websocketDisconnectionsChannel = make(chan string)
var websocketConnectionsChannel = make(chan []string)

type Conn struct {
	b  []byte
	rc chan []byte
	w  *websocket.Conn
}

//export NewUuid
func NewUuid(env *C.Environment, udfc *C.UDFContext, out *C.UDFValue) {
	c_newUuid := C.CString(uuid.NewString())
	defer C.free(unsafe.Pointer(c_newUuid))
	C.SetSymbolUDFValue(env, out, c_newUuid)
}

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
	sessionId := s.Values["ID"].(string)
	c, err := upgrader.Upgrade(w, r, w.Header())
	defer c.Close()
	if err != nil {
		log.Print("ERROR: upgrade failed:", err)
		return
	}

	websocketId := uuid.NewString()
	websocketReadChan := make(chan []byte, 1)
	websockets[websocketId] = &Conn{[]byte{}, websocketReadChan, c}
	websocketConnectionsChannel <- []string{sessionId, websocketId}
	defer WebsocketDisconnection(websocketId)

	for {
		_, message, err := c.ReadMessage()
		if err != nil {
			log.Println("INFO: error reading message:", err)
			break
		}
		log.Printf("INFO: received message from user %s on websocket %s", sessionId, websocketId)
		websocketReadChan <- append(message, byte('\n'))
		websocketMessageBufferedChannel <- websocketId
	}
}

func WebsocketDisconnection(id string) {
	log.Printf("INFO: websocket %s disconnected", id)
	websocketDisconnectionsChannel <- id
}

func StartRulesEngine() {
	env := C.CreateEnvironment()
	defer C.DestroyEnvironment(env)
	c_f := C.CString("euchre.bat")
	defer C.free(unsafe.Pointer(c_f))
	C.BatchStar(env, c_f)
	for {
		select {
		case wsid := <-websocketMessageBufferedChannel:
			log.Printf("INFO: telling CLIPS about buffered message from websocket id %s", wsid)
			AssertString(env, fmt.Sprintf("(received-message-from %s)", wsid))
		case sid_wsid := <-websocketConnectionsChannel:
			log.Printf("INFO: telling CLIPS about user %s connection on websocket id %s", sid_wsid[0], sid_wsid[1])
			Connect(env, sid_wsid[0], sid_wsid[1])
		case wsid := <-websocketDisconnectionsChannel:
			log.Printf("INFO: telling CLIPS about user disconnect from websocket id %s", wsid)
			Disconnect(env, wsid)
		}
		C.Run(env, -1)
	}
}

func AssertString(e *C.Environment, fact string) {
	fact_c := C.CString(fact)
	defer C.free(unsafe.Pointer(fact_c))
	C.AssertString(e, fact_c)
}

func Connect(e *C.Environment, sid string, wsid string) {
	CreateRouterForWebsocketConnection(e, wsid)
	id_fact := fmt.Sprintf("(connection (sid %s) (wsid %s))", sid, wsid)
	AssertString(e, id_fact)
}

func Disconnect(e *C.Environment, wsid string) {
	dc_fact := fmt.Sprintf("(disconnection %s)", wsid)
	AssertString(e, dc_fact)
	id_c := C.CString(wsid)
	defer C.free(unsafe.Pointer(id_c))
	C.DeleteRouter(e, id_c)
	delete(websockets, wsid)
}

//export QueryWsCallback
func QueryWsCallback(e *C.Environment, logicalName *C.cchar_t, _ unsafe.Pointer) C.bool {
	_, ok := websockets[C.GoString(logicalName)]
	return C.bool(ok)
}

//export WriteWsCallback
func WriteWsCallback(e *C.Environment, logicalName *C.cchar_t, str *C.cchar_t, context unsafe.Pointer) {
	if err := websockets[C.GoString(logicalName)].w.WriteMessage(1, []byte(C.GoString(str))); err != nil {
		log.Printf("WARNING: attempting to send message to socket %s errored: %s", C.GoString(logicalName), err)
	}
}

//export ReadWsCallback
func ReadWsCallback(e *C.Environment, logicalName *C.cchar_t, context unsafe.Pointer) C.int {
	wsid := C.GoString(logicalName)
	websocket := websockets[wsid]
	if len(websocket.b) == 0 {
		websocket.b = append(websocket.b, <-websocket.rc...)
	}
	ch := websocket.b[0]
	websocket.b = websocket.b[1:]
	return C.int(ch)
}

//export UnreadWsCallback
func UnreadWsCallback(e *C.Environment, logicalName *C.cchar_t, ch C.int, context unsafe.Pointer) C.int {
	wsid := C.GoString(logicalName)
	websockets[wsid].b = append([]byte{byte(ch)}, websockets[wsid].b...)
	return C.int(ch)
}

//export ExitWsCallback
func ExitWsCallback(e *C.Environment, exitCode C.int, context unsafe.Pointer) {}

func CreateRouterForWebsocketConnection(e *C.Environment, id string) {
	id_c := C.CString(id)
	defer C.free(unsafe.Pointer(id_c))
	C.AddRouter(
		e, id_c, 20,
		(*C.RouterQueryFunction)((unsafe.Pointer)(C.QueryWsCallback)),
		(*C.RouterWriteFunction)((unsafe.Pointer)(C.WriteWsCallback)),
		(*C.RouterReadFunction)((unsafe.Pointer)(C.ReadWsCallback)),
		(*C.RouterUnreadFunction)((unsafe.Pointer)(C.UnreadWsCallback)),
		(*C.RouterExitFunction)((unsafe.Pointer)(C.ExitWsCallback)),
		nil)
}

func main() {
	flag.Parse()
	http.HandleFunc("/websocket", Websocket)
	go StartRulesEngine()
	http.ListenAndServe(*addr, nil)
}
