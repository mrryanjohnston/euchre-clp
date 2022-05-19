FROM golang:1.18

WORKDIR /usr/src/app
COPY go.mod go.sum ./
ENV GOPROXY=direct
RUN go mod tidy
RUN go mod download
RUN go mod verify

COPY . .
RUN go build -v -o /usr/local/bin/app .

CMD ["app"]
