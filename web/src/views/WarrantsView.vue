<template>
  <div class="space-y-4">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-foreground">Warrants</h2>
        <div class="flex gap-1">
          <button
            class="text-xs px-2 py-1 rounded-lg transition-colors"
            :class="tab === 'active' ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground hover:text-foreground'"
            @click="tab = 'active'"
          >Active ({{ activeWarrants.length }})</button>
          <button
            class="text-xs px-2 py-1 rounded-lg transition-colors"
            :class="tab === 'executed' ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground hover:text-foreground'"
            @click="tab = 'executed'"
          >Executed ({{ executedWarrants.length }})</button>
        </div>
      </div>
      <button
        class="text-xs bg-primary text-primary-foreground px-3 py-1.5 rounded-lg font-medium hover:bg-primary/90 transition-colors"
        @click="showCreate = true"
      >+ Issue Warrant</button>
    </div>

    <!-- Warrant list -->
    <div class="space-y-2">
      <div v-if="displayedWarrants.length === 0" class="text-center py-12">
        <Gavel class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
        <p class="text-sm text-muted-foreground">No {{ tab }} warrants</p>
      </div>

      <div
        v-for="warrant in displayedWarrants"
        :key="warrant.id"
        class="flex items-center gap-4 p-4 rounded-xl bg-card border border-border"
      >
        <Gavel class="w-5 h-5 shrink-0" :class="warrant.status === 'active' ? 'text-red-400' : 'text-green-400'" />
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-foreground">{{ warrant.suspectName }}</p>
          <p class="text-xs text-muted-foreground mt-0.5">{{ warrant.charges }}</p>
          <p class="text-xs text-muted-foreground">Issued by {{ warrant.issuedBy }} · {{ warrant.issuedAt }}</p>
        </div>
        <button
          v-if="warrant.status === 'active'"
          class="text-xs px-3 py-1.5 rounded-lg bg-green-500/10 text-green-400 border border-green-500/20 hover:bg-green-500/20 transition-colors font-medium"
          @click="executeWarrant(warrant.id)"
        >Execute</button>
        <span v-else class="text-xs text-muted-foreground">
          Executed by {{ warrant.executedBy }} · {{ warrant.executedAt }}
        </span>
      </div>
    </div>

    <!-- Issue warrant modal -->
    <Teleport to="body">
      <Transition name="fade">
        <div v-if="showCreate" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50" @click.self="showCreate = false">
          <div class="w-full max-w-md rounded-xl bg-card border border-border p-6 space-y-4">
            <h3 class="text-base font-semibold text-foreground">Issue Warrant</h3>
            <input v-model="form.suspectName" placeholder="Suspect name" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <input v-model="form.suspectCitizenid" placeholder="Citizen ID" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <input v-model="form.charges" placeholder="Charges" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <textarea v-model="form.description" placeholder="Description / details" rows="3" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground resize-none" />
            <div class="flex justify-end gap-2 pt-2">
              <button class="text-sm px-4 py-2 rounded-lg text-muted-foreground hover:text-foreground transition-colors" @click="showCreate = false">Cancel</button>
              <button
                class="text-sm px-4 py-2 rounded-lg bg-red-500/80 text-white font-medium hover:bg-red-500 transition-colors"
                :disabled="warrantStore.loading"
                @click="submitWarrant"
              >Issue Warrant</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed, reactive } from 'vue'
import { Gavel } from 'lucide-vue-next'
import { useWarrantStore } from '@/stores/warrantStore'

const warrantStore = useWarrantStore()
const tab = ref<'active' | 'executed'>('active')
const showCreate = ref(false)

const form = reactive({
  suspectName: '',
  suspectCitizenid: '',
  charges: '',
  description: '',
})

const activeWarrants = computed(() => warrantStore.warrants.filter(w => w.status === 'active'))
const executedWarrants = computed(() => warrantStore.warrants.filter(w => w.status === 'executed'))
const displayedWarrants = computed(() => tab.value === 'active' ? activeWarrants.value : executedWarrants.value)

async function executeWarrant(id: number) {
  await warrantStore.execute(id)
}

async function submitWarrant() {
  await warrantStore.issue({ ...form })
  showCreate.value = false
  form.suspectName = ''
  form.suspectCitizenid = ''
  form.charges = ''
  form.description = ''
}
</script>
