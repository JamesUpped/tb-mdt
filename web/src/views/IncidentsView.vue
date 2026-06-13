<template>
  <div class="space-y-4">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-foreground">Incidents</h2>
        <span class="text-xs text-muted-foreground">({{ incidentStore.incidents.length }})</span>
      </div>
      <button
        class="text-xs bg-primary text-primary-foreground px-3 py-1.5 rounded-lg font-medium hover:bg-primary/90 transition-colors"
        @click="showCreate = true"
      >+ New Incident</button>
    </div>

    <!-- Incident list -->
    <div class="space-y-2">
      <div v-if="incidentStore.incidents.length === 0" class="text-center py-12">
        <FileText class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
        <p class="text-sm text-muted-foreground">No incidents filed yet</p>
      </div>

      <div
        v-for="incident in incidentStore.incidents"
        :key="incident.id"
        class="p-4 rounded-xl bg-card border border-border hover:border-border/80 transition-colors cursor-pointer"
        @click="selectIncident(incident)"
      >
        <div class="flex items-center gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <p class="text-sm font-medium text-foreground truncate">{{ incident.title }}</p>
              <span class="text-[10px] font-mono text-muted-foreground">Case #{{ incident.caseNumber }}</span>
            </div>
            <p class="text-xs text-muted-foreground mt-1 line-clamp-1">{{ incident.description }}</p>
          </div>
          <span
            class="text-xs px-2 py-1 rounded-lg border capitalize shrink-0"
            :class="incident.status === 'open' ? 'border-amber-500/30 text-amber-400 bg-amber-500/5' : 'border-green-500/30 text-green-400 bg-green-500/5'"
          >{{ incident.status }}</span>
          <div class="flex items-center gap-1">
            <button
              v-if="incident.status === 'open'"
              title="Close incident"
              class="w-8 h-8 rounded-lg flex items-center justify-center text-muted-foreground hover:text-green-400 hover:bg-green-500/10 transition-colors"
              @click.stop="closeIncident(incident.id)"
            >
              <CheckCircle class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Detail panel -->
    <Teleport to="body">
      <Transition name="fade">
        <div v-if="selected" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50" @click.self="selected = null">
          <div class="w-full max-w-2xl rounded-xl bg-card border border-border p-6 space-y-4 max-h-[80vh] overflow-auto">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-base font-semibold text-foreground">{{ selected.title }}</h3>
                <p class="text-xs text-muted-foreground">Case #{{ selected.caseNumber }} · Created {{ selected.createdAt }}</p>
              </div>
              <button class="w-8 h-8 rounded-lg flex items-center justify-center text-muted-foreground hover:text-foreground" @click="selected = null">
                <X class="w-4 h-4" />
              </button>
            </div>

            <p class="text-sm text-foreground/80">{{ selected.description }}</p>

            <div class="grid grid-cols-2 gap-4 text-xs">
              <div>
                <p class="text-muted-foreground mb-1">Location</p>
                <p class="text-foreground">{{ selected.location || '—' }}</p>
              </div>
              <div>
                <p class="text-muted-foreground mb-1">Created By</p>
                <p class="text-foreground">{{ selected.createdBy }}</p>
              </div>
              <div>
                <p class="text-muted-foreground mb-1">Officers</p>
                <p class="text-foreground">{{ selected.officers?.join(', ') || '—' }}</p>
              </div>
              <div>
                <p class="text-muted-foreground mb-1">Suspects</p>
                <p class="text-foreground">{{ selected.suspects?.join(', ') || '—' }}</p>
              </div>
            </div>

            <!-- Evidence section -->
            <div>
              <h4 class="text-sm font-medium text-foreground mb-2">Evidence</h4>
              <div v-if="incidentStore.evidence.length === 0" class="text-xs text-muted-foreground">No evidence attached</div>
              <div v-else class="space-y-1">
                <div v-for="e in incidentStore.evidence" :key="e.id" class="flex items-center gap-2 text-xs p-2 rounded-lg bg-secondary/40">
                  <Camera class="w-3 h-3 text-muted-foreground" />
                  <span class="text-foreground">{{ e.description }}</span>
                  <span class="text-muted-foreground ml-auto">{{ e.type }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Create incident modal -->
    <Teleport to="body">
      <Transition name="fade">
        <div v-if="showCreate" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50" @click.self="showCreate = false">
          <div class="w-full max-w-lg rounded-xl bg-card border border-border p-6 space-y-4">
            <h3 class="text-base font-semibold text-foreground">Create Incident</h3>
            <input v-model="form.title" placeholder="Title" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <textarea v-model="form.description" placeholder="Description" rows="4" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground resize-none" />
            <input v-model="form.location" placeholder="Location" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <input v-model="form.suspects" placeholder="Suspects (comma separated)" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <div class="flex justify-end gap-2 pt-2">
              <button class="text-sm px-4 py-2 rounded-lg text-muted-foreground hover:text-foreground transition-colors" @click="showCreate = false">Cancel</button>
              <button
                class="text-sm px-4 py-2 rounded-lg bg-primary text-primary-foreground font-medium hover:bg-primary/90 transition-colors"
                :disabled="incidentStore.loading"
                @click="submitIncident"
              >Create</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script lang="ts" setup>
import { ref, reactive } from 'vue'
import { FileText, CheckCircle, X, Camera } from 'lucide-vue-next'
import { useIncidentStore } from '@/stores/incidentStore'
import type { IncidentRecord } from '@/types'

const incidentStore = useIncidentStore()
const showCreate = ref(false)
const selected = ref<IncidentRecord | null>(null)

const form = reactive({
  title: '',
  description: '',
  location: '',
  suspects: '',
})

function selectIncident(incident: IncidentRecord) {
  selected.value = incident
  incidentStore.loadEvidence(incident.id)
}

async function closeIncident(id: number) {
  await incidentStore.close(id)
}

async function submitIncident() {
  await incidentStore.create({
    title: form.title,
    description: form.description,
    location: form.location,
    suspects: form.suspects.split(',').map(s => s.trim()).filter(Boolean),
  })
  showCreate.value = false
  form.title = ''
  form.description = ''
  form.location = ''
  form.suspects = ''
}
</script>
