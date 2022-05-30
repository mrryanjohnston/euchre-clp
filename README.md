# euchre.go

## Requirements

You'll need to get [Docker](https://www.docker.com/) or
[Go](https://go.dev/) installed in order to run this server.

## Starting the server

Using the `server.sh` executable will use Docker to run the server:

```
./server.sh
```

### Old/Aleternative methods

You can manually build / run the docker container like this:

```
docker build -t euchre .
docker run -p 8765:8765/tcp -it --rm --name euchre-running euchre
```

You can also manually run the server with Go like this:

```
go run .
```
