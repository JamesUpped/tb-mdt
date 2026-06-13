<template>
  <div class="flex items-center justify-between text-xs">
    <span class="text-muted-foreground">{{ label }}</span>
    <span class="text-foreground font-medium">{{ value || '—' }}</span>
  </div>
</template>

<script lang="ts" setup>
defineProps<{
  label: string
  value: string
}>()
</script>
