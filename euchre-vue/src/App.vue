<script setup>
import { ref } from 'vue';
import { RouterLink, RouterView } from "vue-router";
import HelloWorld from "./components/HelloWorld.vue";
import UserCount from "./components/UserCount.vue";

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
</script>

<template>
  <header>
    <img
      alt="Euchre Jack"
      class="logo"
      src="@/assets/euchrejack.png"
      width="200"
      height="236"
    />

    <div class="wrapper">
      <HelloWorld msg="Euchre" />
      <UserCount :socket="socket" />
    </div>
  </header>

  <RouterView v-if="connected" :socket="socket" />
</template>

<style scoped>
header {
  line-height: 1.5;
  max-height: 100vh;
}

.logo {
  display: block;
  margin: 0 auto 2rem;
}

nav {
  width: 100%;
  font-size: 12px;
  text-align: center;
  margin-top: 2rem;
}

nav a.router-link-exact-active {
  color: var(--color-text);
}

nav a.router-link-exact-active:hover {
  background-color: transparent;
}

nav a {
  display: inline-block;
  padding: 0 1rem;
  border-left: 1px solid var(--color-border);
}

nav a:first-of-type {
  border: 0;
}

@media (min-width: 1024px) {
  header {
    display: flex;
    place-items: center;
    padding-right: calc(var(--section-gap) / 2);
  }

  .logo {
    margin: 0 2rem 0 0;
  }

  header .wrapper {
    display: flex;
    place-items: flex-start;
    flex-wrap: wrap;
  }

  nav {
    text-align: left;
    margin-left: -1rem;
    font-size: 1rem;

    padding: 1rem 0;
    margin-top: 1rem;
  }
}
</style>
