import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { DispatchCall } from '@/types'

export const useDispatchStore = defineStore('dispatch', () => {
  const calls = ref<DispatchCall[]>([])
  const loading = ref(false)

  function setCalls(data: DispatchCall[]) {
    calls.value = data
  }

  async function createCall(payload: Partial<DispatchCall>) {
    loading.value = true
    try {
      const result = await fetchNui<{ success: boolean }>('createCall', payload as Record<string, unknown>)
      return result
    } finally {
      loading.value = false
    }
  }

  async function assignCall(callId: number, officerId: number) {
    return fetchNui<{ success: boolean }>('assignCall', { callId, officerId })
  }

  async function updateCallStatus(callId: number, status: string) {
    return fetchNui<{ success: boolean }>('updateCallStatus', { callId, status })
  }

  return { calls, loading, setCalls, createCall, assignCall, updateCallStatus }
})
