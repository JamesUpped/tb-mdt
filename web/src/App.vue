<template>
  <!-- Panic alert banner — renders even when the MDT is closed -->
  <Transition name="fade">
    <div v-if="panicAlert" class="fixed top-6 left-1/2 -translate-x-1/2 z-[60] pointer-events-none">
      <div class="flex items-center gap-3 px-5 py-3 rounded-xl bg-red-950/95 border-2 border-red-500 shadow-2xl shadow-red-500/30 animate-pulse">
        <Siren class="w-6 h-6 text-red-400" />
        <div>
          <p class="text-sm font-bold text-red-300 tracking-wide">OFFICER PANIC</p>
          <p class="text-xs text-red-200">{{ panicAlert.officer }} ({{ panicAlert.callsign }}) — location marked on GPS</p>
        </div>
      </div>
    </div>
  </Transition>

  <Transition name="fade">
    <div v-if="appStore.isOpen" class="fixed inset-0 flex items-center justify-center p-8 pointer-events-none">
      <div class="w-full h-full max-w-[1400px] max-h-[900px] pointer-events-auto">
        <MDTLayout />
      </div>
    </div>
  </Transition>
</template>

<script lang="ts" setup>
import './style.css'
import { onMounted, onUnmounted, ref } from 'vue'
import { Siren } from 'lucide-vue-next'
import { useAppStore } from '@/stores/appStore'
import { useDispatchStore } from '@/stores/dispatchStore'
import { useOfficerStore } from '@/stores/officerStore'
import { useIncidentStore } from '@/stores/incidentStore'
import { useWarrantStore } from '@/stores/warrantStore'
import { useBoloStore } from '@/stores/boloStore'
import { useAnnouncementStore } from '@/stores/announcementStore'
import { fetchNui } from '@/composables/fetchNui'
import MDTLayout from '@/components/layout/MDTLayout.vue'
import type { PanicAlert } from '@/types'

const appStore = useAppStore()
const dispatchStore = useDispatchStore()
const officerStore = useOfficerStore()
const incidentStore = useIncidentStore()
const warrantStore = useWarrantStore()
const boloStore = useBoloStore()
const announcementStore = useAnnouncementStore()

const panicAlert = ref<PanicAlert | null>(null)
let panicTimeout: ReturnType<typeof setTimeout> | null = null

function onMessage(event: MessageEvent) {
  const { action, data, player, config } = event.data

  switch (action) {
    case 'openMDT':
      appStore.open(player, config)
      if (data) {
        if (data.calls) dispatchStore.setCalls(data.calls)
        if (data.officers) officerStore.setOfficers(data.officers)
        if (data.incidents) incidentStore.setIncidents(data.incidents)
        if (data.warrants) warrantStore.setWarrants(data.warrants)
        if (data.bolos) boloStore.setBolos(data.bolos)
      }
      break

    case 'closeMDT':
      appStore.close()
      break

    case 'updateCalls':
      if (data) dispatchStore.setCalls(data)
      break

    case 'updateOfficers':
      if (data) officerStore.setOfficers(data)
      break

    case 'newCall':
      if (data) dispatchStore.calls.unshift(data)
      break

    case 'callAssigned':
      break

    case 'newWarrant':
      if (data) warrantStore.warrants.unshift(data)
      break

    case 'newBOLO':
      if (data) boloStore.bolos.unshift(data)
      break

    case 'newIncident':
      if (data) incidentStore.incidents.unshift(data)
      break

    case 'newAnnouncement':
      if (data) announcementStore.push(data)
      break

    case 'panicAlert':
      if (data) {
        panicAlert.value = data
        if (panicTimeout) clearTimeout(panicTimeout)
        panicTimeout = setTimeout(() => { panicAlert.value = null }, 12000)
      }
      break
  }
}

function onKeyDown(e: KeyboardEvent) {
  if (e.key === 'Escape' && appStore.isOpen) {
    appStore.close()
    fetchNui('close')
  }
}

onMounted(() => {
  window.addEventListener('message', onMessage)
  document.addEventListener('keydown', onKeyDown)
})

onUnmounted(() => {
  window.removeEventListener('message', onMessage)
  document.removeEventListener('keydown', onKeyDown)
})
</script>
