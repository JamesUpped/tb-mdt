<template>
  <div class="rounded-xl bg-card border border-border p-4 flex items-center gap-4">
    <div class="w-10 h-10 rounded-lg flex items-center justify-center" :class="bgClass">
      <component :is="iconComponent" class="w-5 h-5" :class="textClass" />
    </div>
    <div>
      <p class="text-2xl font-bold text-foreground tabular-nums">{{ value }}</p>
      <p class="text-xs text-muted-foreground">{{ label }}</p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue'
import { Radio, Users, FileText, Gavel } from 'lucide-vue-next'

const props = defineProps<{
  label: string
  value: number
  icon: string
  color: 'blue' | 'green' | 'amber' | 'red'    
}>()

const iconMap: Record<string, typeof Radio> = { Radio, Users, FileText, Gavel }
const iconComponent = computed(() => iconMap[props.icon] ?? Radio)

const colorMap = {
  blue:  { bg: 'bg-blue-500/10', text: 'text-blue-400' },
  green: { bg: 'bg-green-500/10', text: 'text-green-400' },
  amber: { bg: 'bg-amber-500/10', text: 'text-amber-400' },
  red:   { bg: 'bg-red-500/10', text: 'text-red-400' },
}

const bgClass = computed(() => colorMap[props.color].bg)
const textClass = computed(() => colorMap[props.color].text)
</script>
