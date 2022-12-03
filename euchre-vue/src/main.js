import { createApp, ref } from "vue";
import { createPinia } from "pinia";

import App from "./App.vue";
import router from "./router";

import "./assets/main.css";

const app = createApp(App);

app.use(createPinia());
app.use(router);

const socket = new WebSocket('ws://localhost:5173/websocket');
const connected = ref(false);

socket.addEventListener("open", () => {
  connected.value = true;
});
socket.addEventListener("close", () => {
  connected.value = false;
});
socket.addEventListener("error", () => {
  connected.value = false;
});
const events = {
  games: new Event('games'),
};
socket.addEventListener("message", (event) => {
  const name = event.data.split(' ').shift();
  const customEvent =
    new CustomEvent(name, {
      detail: event.data.substring(name.length + 1, event.data.length),
    });
  socket.dispatchEvent(customEvent);
});

app.provide('socket', socket);
app.provide('connected', connected);

app.mount("#app");
