<template>
  <header class="h-14 flex items-center justify-between px-6 border-b border-border bg-card/50 shrink-0">
    <!-- Left: view title -->
    <h1 class="text-lg font-semibold capitalize text-foreground">
      {{ appStore.currentView === 'bolos' ? 'BOLOs' : appStore.currentView }}
    </h1>

    <!-- Right: officer info + clock + close -->
    <div class="flex items-center gap-4">
      <!-- Live clock -->
      <span class="text-sm text-muted-foreground font-mono tabular-nums">{{ clock }}</span>

      <!-- Officer badge -->
      <div class="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-secondary/60 border border-border">
        <div class="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
        <span class="text-xs font-medium text-foreground">{{ appStore.player?.callsign }}</span>
        <span class="text-xs text-muted-foreground">{{ appStore.player?.name }}</span>
      </div>

      <!-- Close button -->
      <button
        title="Close MDT (ESC)"
        class="w-8 h-8 rounded-lg flex items-center justify-center text-muted-foreground hover:text-destructive-foreground hover:bg-destructive/20 transition-colors"
        @click="closeMDT"
      >
        <X class="w-4 h-4" />
      </button>
    </div>
  </header>
</template>

<script lang="ts" setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { X } from 'lucide-vue-next'
import { useAppStore } from '@/stores/appStore'
import { fetchNui } from '@/composables/fetchNui'
import dayjs from 'dayjs'

const appStore = useAppStore()
const clock = ref(dayjs().format('HH:mm:ss'))

let interval: ReturnType<typeof setInterval>

onMounted(() => {
  interval = setInterval(() => {
    clock.value = dayjs().format('HH:mm:ss')
  }, 1000)
})

onUnmounted(() => clearInterval(interval))

function closeMDT() {
  appStore.close()
  fetchNui('close')
}
</script>
