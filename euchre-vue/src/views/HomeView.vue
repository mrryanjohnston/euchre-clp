<script setup>
import TheWelcome from "../components/TheWelcome.vue";
defineProps({
  socket: {
    type: Object,
    required: true
  }
});
</script>

<template>
  <main>
    <TheWelcome :socket="socket" />
  </main>
</template>
