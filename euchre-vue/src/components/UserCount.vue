<script setup>
import { inject, ref } from 'vue';
const connected = inject('connected');
const socket = inject('socket');
const users = ref(0);
socket.addEventListener('users-online', (count) => {
  users.value = count.detail;
});
</script>

<template>
  <h4>Users online: {{users}}</h4>
</template>
