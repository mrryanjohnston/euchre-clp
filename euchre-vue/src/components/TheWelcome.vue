<script setup>
import { inject, ref } from 'vue';

const games = ref([]);
const socket = inject('socket');
socket.addEventListener('games', (g) => {
  games.value = g.detail.split(' ');
});
socket.send('create-game');
socket.send('list-games');
</script>

<template>
  <h2>Games</h2>
  <table>
    <tr>
      <th>id</th>
      <th>players</th>
      <th>spectators</th>
    </tr>
    <tr v-for="game in games">
      <td>
        <a :href="game" @click.prevent="">{{game}}</a>
      </td>
      <td>
        0
      </td>
      <td>
        0
      </td>
    </tr>
  </table>
</template>
