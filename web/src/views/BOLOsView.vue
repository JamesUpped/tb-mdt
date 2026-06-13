<template>
  <div class="space-y-4">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-foreground">BOLOs</h2>
        <div class="flex gap-1">
          <button
            class="text-xs px-2 py-1 rounded-lg transition-colors"
            :class="tab === 'active' ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground hover:text-foreground'"
            @click="tab = 'active'"
          >Active ({{ activeBolos.length }})</button>
          <button
            class="text-xs px-2 py-1 rounded-lg transition-colors"
            :class="tab === 'inactive' ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground hover:text-foreground'"
            @click="tab = 'inactive'"
          >Inactive ({{ inactiveBolos.length }})</button>
        </div>
      </div>
      <button
        class="text-xs bg-primary text-primary-foreground px-3 py-1.5 rounded-lg font-medium hover:bg-primary/90 transition-colors"
        @click="showCreate = true"
      >+ Create BOLO</button>
    </div>

    <!-- BOLO list -->
    <div class="space-y-2">
      <div v-if="displayedBolos.length === 0" class="text-center py-12">
        <AlertTriangle class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
        <p class="text-sm text-muted-foreground">No {{ tab }} BOLOs</p>
      </div>

      <div
        v-for="bolo in displayedBolos"
        :key="bolo.id"
        class="flex items-center gap-4 p-4 rounded-xl bg-card border border-border"
      >
        <div class="w-10 h-10 rounded-lg flex items-center justify-center shrink-0"
          :class="bolo.type === 'person' ? 'bg-amber-500/10' : 'bg-blue-500/10'"
        >
          <User v-if="bolo.type === 'person'" class="w-5 h-5 text-amber-400" />
          <Car v-else class="w-5 h-5 text-blue-400" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <p class="text-sm font-medium text-foreground truncate">{{ bolo.reason }}</p>
            <span class="text-[10px] px-1.5 py-0.5 rounded border capitalize"
              :class="bolo.type === 'person' ? 'border-amber-500/30 text-amber-400' : 'border-blue-500/30 text-blue-400'"
            >{{ bolo.type }}</span>
          </div>
          <p class="text-xs text-muted-foreground mt-0.5 line-clamp-1">{{ bolo.description }}</p>
          <p class="text-xs text-muted-foreground">
            {{ bolo.plate ? `Plate: ${bolo.plate} · ` : '' }}
            {{ bolo.suspectName ? `Suspect: ${bolo.suspectName} · ` : '' }}
            Created by {{ bolo.createdBy }} · {{ bolo.createdAt }}
          </p>
        </div>
        <button
          v-if="bolo.status === 'active'"
          class="text-xs px-3 py-1.5 rounded-lg text-muted-foreground hover:text-destructive-foreground hover:bg-destructive/10 border border-border transition-colors"
          @click="deactivate(bolo.id)"
        >Deactivate</button>
      </div>
    </div>

    <!-- Create BOLO modal -->
    <Teleport to="body">
      <Transition name="fade">
        <div v-if="showCreate" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50" @click.self="showCreate = false">
          <div class="w-full max-w-md rounded-xl bg-card border border-border p-6 space-y-4">
            <h3 class="text-base font-semibold text-foreground">Create BOLO</h3>
            <select v-model="form.type" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring">
              <option value="person">Person</option>
              <option value="vehicle">Vehicle</option>
            </select>
            <input v-if="form.type === 'person'" v-model="form.suspectName" placeholder="Suspect name" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <input v-if="form.type === 'vehicle'" v-model="form.plate" placeholder="Plate number" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <input v-model="form.reason" placeholder="Reason" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <textarea v-model="form.description" placeholder="Description" rows="3" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground resize-none" />
            <div class="flex justify-end gap-2 pt-2">
              <button class="text-sm px-4 py-2 rounded-lg text-muted-foreground hover:text-foreground transition-colors" @click="showCreate = false">Cancel</button>
              <button
                class="text-sm px-4 py-2 rounded-lg bg-amber-500/80 text-white font-medium hover:bg-amber-500 transition-colors"
                :disabled="boloStore.loading"
                @click="submitBOLO"
              >Create BOLO</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed, reactive } from 'vue'
import { AlertTriangle, User, Car } from 'lucide-vue-next'
import { useBoloStore } from '@/stores/boloStore'

const boloStore = useBoloStore()
const tab = ref<'active' | 'inactive'>('active')
const showCreate = ref(false)

const form = reactive({
  type: 'person' as 'person' | 'vehicle',
  suspectName: '',
  plate: '',
  reason: '',
  description: '',
})

const activeBolos = computed(() => boloStore.bolos.filter(b => b.status === 'active'))
const inactiveBolos = computed(() => boloStore.bolos.filter(b => b.status === 'inactive'))
const displayedBolos = computed(() => tab.value === 'active' ? activeBolos.value : inactiveBolos.value)

async function deactivate(id: number) {
  await boloStore.deactivate(id)
}

async function submitBOLO() {
  await boloStore.create({ ...form })
  showCreate.value = false
  form.type = 'person'
  form.suspectName = ''
  form.plate = ''
  form.reason = ''
  form.description = ''
}
</script>
