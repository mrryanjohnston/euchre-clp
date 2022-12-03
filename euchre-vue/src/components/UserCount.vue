<script setup>
import { ref } from 'vue';
const { socket } = defineProps({
  socket: {
    type: Object,
    required: true
  }
});
const users = ref(0);
socket.addEventListener('users-online', (count) => {
  users.value = count.detail;
});
</script>

<template>
  <h4>Users online: {{users}}</h4>
</template>
