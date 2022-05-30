#!/usr/bin/env sh
docker build -t euchre .
docker run -p 8765:8765/tcp -it --rm --name euchre-running euchre
