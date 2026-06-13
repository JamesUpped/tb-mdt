<template>
  <div class="space-y-4">
    <h2 class="text-lg font-semibold text-foreground">Evidence Locker</h2>

    <!-- Select incident to view evidence -->
    <div class="flex items-center gap-3">
      <select
        v-model="selectedIncidentId"
        class="flex-1 text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring"
        @change="loadEvidence"
      >
        <option :value="0" disabled>Select an incident...</option>
        <option v-for="incident in incidentStore.incidents" :key="incident.id" :value="incident.id">
          Case #{{ incident.caseNumber }} — {{ incident.title }}
        </option>
      </select>
      <button
        v-if="selectedIncidentId"
        class="text-xs bg-primary text-primary-foreground px-3 py-1.5 rounded-lg font-medium hover:bg-primary/90 transition-colors"
        @click="showAdd = true"
      >+ Add Evidence</button>
    </div>

    <!-- Evidence list -->
    <div v-if="selectedIncidentId" class="space-y-2">
      <div v-if="incidentStore.evidence.length === 0" class="text-center py-8">
        <Camera class="w-10 h-10 text-muted-foreground/30 mx-auto mb-2" />
        <p class="text-sm text-muted-foreground">No evidence attached to this incident</p>
      </div>

      <div
        v-for="item in incidentStore.evidence"
        :key="item.id"
        class="flex items-center gap-4 p-4 rounded-xl bg-card border border-border"
      >
        <div class="w-10 h-10 rounded-lg bg-secondary flex items-center justify-center shrink-0">
          <component :is="evidenceIcon(item.type)" class="w-5 h-5 text-muted-foreground" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-foreground truncate">{{ item.description }}</p>
          <p class="text-xs text-muted-foreground">
            Type: {{ item.type }} · Added by {{ item.addedBy }} · {{ item.addedAt }}
          </p>
        </div>
      </div>
    </div>

    <!-- Empty state: no incident selected -->
    <div v-if="!selectedIncidentId" class="text-center py-12">
      <Camera class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
      <p class="text-sm text-muted-foreground">Select an incident to view its evidence</p>
    </div>

    <!-- Add evidence modal -->
    <Teleport to="body">
      <Transition name="fade">
        <div v-if="showAdd" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50" @click.self="showAdd = false">
          <div class="w-full max-w-md rounded-xl bg-card border border-border p-6 space-y-4">
            <h3 class="text-base font-semibold text-foreground">Add Evidence</h3>
            <select v-model="form.type" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring">
              <option value="photo">Photo</option>
              <option value="dna">DNA</option>
              <option value="fingerprint">Fingerprint</option>
              <option value="weapon">Weapon</option>
              <option value="document">Document</option>
              <option value="cctv">CCTV</option>
              <option value="testimony">Testimony</option>
              <option value="other">Other</option>
            </select>
            <textarea v-model="form.description" placeholder="Evidence description" rows="3" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground resize-none" />
            <input v-model="form.metadata" placeholder="Additional metadata (optional)" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <div class="flex justify-end gap-2 pt-2">
              <button class="text-sm px-4 py-2 rounded-lg text-muted-foreground hover:text-foreground transition-colors" @click="showAdd = false">Cancel</button>
              <button
                class="text-sm px-4 py-2 rounded-lg bg-primary text-primary-foreground font-medium hover:bg-primary/90 transition-colors"
                @click="submitEvidence"
              >Add</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script lang="ts" setup>
import { ref, reactive } from 'vue'
import { Camera, Fingerprint, FileText, Crosshair, Video, MessageSquare, Package } from 'lucide-vue-next'
import { useIncidentStore } from '@/stores/incidentStore'

const incidentStore = useIncidentStore()
const selectedIncidentId = ref(0)
const showAdd = ref(false)

const form = reactive({
  type: 'photo',
  description: '',
  metadata: '',
})

function evidenceIcon(type: string) {
  const map: Record<string, typeof Camera> = {
    photo: Camera,
    dna: Fingerprint,
    fingerprint: Fingerprint,
    weapon: Crosshair,
    document: FileText,
    cctv: Video,
    testimony: MessageSquare,
  }
  return map[type] ?? Package
}

function loadEvidence() {
  if (selectedIncidentId.value) {
    incidentStore.loadEvidence(selectedIncidentId.value)
  }
}

async function submitEvidence() {
  await incidentStore.addEvidence({
    incidentId: selectedIncidentId.value,
    type: form.type,
    description: form.description,
    metadata: form.metadata || undefined,
  })
  showAdd.value = false
  form.type = 'photo'
  form.description = ''
  form.metadata = ''
  loadEvidence()
}
</script>
