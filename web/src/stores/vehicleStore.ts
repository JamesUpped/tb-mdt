import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { VehicleRecord } from '@/types'

export const useVehicleStore = defineStore('vehicle', () => {
  const results = ref<VehicleRecord[]>([])
  const activeVehicle = ref<VehicleRecord | null>(null)
  const loading = ref(false)

  async function search(query: string) {
    loading.value = true
    try {
      results.value = await fetchNui<VehicleRecord[]>('search', { type: 'vehicle', query })
    } finally {
      loading.value = false
    }
  }

  async function loadProfile(plate: string) {
    loading.value = true
    try {
      activeVehicle.value = await fetchNui<VehicleRecord>('getProfile', { type: 'vehicle', id: plate })
    } finally {
      loading.value = false
    }
  }

  function clearProfile() {
    activeVehicle.value = null
  }

  return { results, activeVehicle, loading, search, loadProfile, clearProfile }
})
