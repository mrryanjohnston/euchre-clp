FROM golang:1.18

WORKDIR /usr/src/app
COPY go.mod ./
COPY go.sum ./
RUN go mod download

COPY *.h ./
COPY *.c ./

COPY *.go ./
RUN go build -v -o /usr/local/bin/app .

COPY *.bat ./
COPY *.clp ./
CMD ["app"]
