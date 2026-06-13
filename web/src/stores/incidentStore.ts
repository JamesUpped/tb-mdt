import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { IncidentRecord, EvidenceRecord } from '@/types'

export const useIncidentStore = defineStore('incident', () => {
  const incidents = ref<IncidentRecord[]>([])
  const activeIncident = ref<IncidentRecord | null>(null)
  const evidence = ref<EvidenceRecord[]>([])
  const loading = ref(false)

  function setIncidents(data: IncidentRecord[]) {
    incidents.value = data
  }

  async function create(payload: Partial<IncidentRecord>) {
    loading.value = true
    try {
      return await fetchNui<{ success: boolean; id?: number }>('createIncident', payload as Record<string, unknown>)
    } finally {
      loading.value = false
    }
  }

  async function close(incidentId: number) {
    return fetchNui<{ success: boolean }>('closeIncident', { incidentId })
  }

  async function loadEvidence(incidentId: number) {
    evidence.value = await fetchNui<EvidenceRecord[]>('getEvidence', { incidentId })
  }

  async function addEvidence(payload: { incidentId: number; type: string; description: string; metadata?: string }) {
    return fetchNui<{ success: boolean }>('addEvidence', payload)
  }

  return { incidents, activeIncident, evidence, loading, setIncidents, create, close, loadEvidence, addEvidence }
})
