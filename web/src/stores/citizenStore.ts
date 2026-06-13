import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchNui } from '@/composables/fetchNui'
import type { CitizenProfile, RapSheet, SelectedCharge } from '@/types'

export const useCitizenStore = defineStore('citizen', () => {
  const results = ref<CitizenProfile[]>([])
  const activeProfile = ref<CitizenProfile | null>(null)
  const rapSheet = ref<RapSheet | null>(null)
  const loading = ref(false)

  async function search(query: string) {
    loading.value = true
    try {
      results.value = await fetchNui<CitizenProfile[]>('search', { type: 'citizen', query })
    } finally {
      loading.value = false
    }
  }

  async function loadProfile(citizenid: string) {
    loading.value = true
    try {
      activeProfile.value = await fetchNui<CitizenProfile>('getProfile', { type: 'citizen', id: citizenid })
      rapSheet.value = null
    } finally {
      loading.value = false
    }
  }

  async function loadRapSheet(citizenid: string): Promise<RapSheet> {
    const data = await fetchNui<RapSheet>('getRapSheet', { citizenid })
    rapSheet.value = data ?? { charges: [], fines: [], points: 0 }
    return rapSheet.value
  }

  async function processCharges(citizenid: string, name: string, charges: SelectedCharge[], incidentId?: number) {
    const payload = {
      citizenid,
      name,
      incidentId,
      charges: charges.map(c => ({ id: c.id, fine: c.fine, jail: c.jail })),
    }
    const result = await fetchNui<{
      success: boolean
      error?: string
      totalFine?: number
      totalJail?: number
      finePaid?: boolean
      jailed?: boolean
      licenseRevoked?: boolean
    }>('processCharges', payload)
    if (result.success) {
      await loadRapSheet(citizenid)
    }
    return result
  }

  async function setLicense(citizenid: string, license: string, status: boolean) {
    const result = await fetchNui<{ success: boolean; error?: string }>('setLicense', { citizenid, license, status })
    if (result.success && activeProfile.value?.citizenid === citizenid) {
      activeProfile.value.licenses = { ...activeProfile.value.licenses, [license]: status }
    }
    return result
  }

  async function saveExtras(citizenid: string, extras: { image: string; notes: string; flags: string[] }) {
    const result = await fetchNui<{ success: boolean; error?: string }>('saveProfileExtras', { citizenid, ...extras })
    if (result.success && activeProfile.value?.citizenid === citizenid) {
      activeProfile.value.image = extras.image
      activeProfile.value.notes = extras.notes
      activeProfile.value.flags = extras.flags
    }
    return result
  }

  function clearProfile() {
    activeProfile.value = null
    rapSheet.value = null
  }

  return {
    results, activeProfile, rapSheet, loading,
    search, loadProfile, loadRapSheet, processCharges, setLicense, saveExtras, clearProfile,
  }
})
