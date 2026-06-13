<template>
  <div class="space-y-4">
    <!-- Header row -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <h2 class="text-lg font-semibold text-foreground">Active Calls</h2>
        <span class="text-xs text-muted-foreground">({{ filteredCalls.length }})</span>
      </div>
      <div class="flex items-center gap-2">
        <!-- Filter -->
        <select
          v-model="filter"
          class="text-xs bg-input border border-border rounded-lg px-3 py-1.5 text-foreground outline-none focus:ring-1 focus:ring-ring"
        >
          <option value="all">All</option>
          <option value="pending">Pending</option>
          <option value="assigned">Assigned</option>
          <option value="en-route">En Route</option>
          <option value="on-scene">On Scene</option>
        </select>
        <!-- Create call -->
        <button
          class="text-xs bg-primary text-primary-foreground px-3 py-1.5 rounded-lg font-medium hover:bg-primary/90 transition-colors"
          @click="showCreate = true"
        >
          + New Call
        </button>
      </div>
    </div>

    <!-- Call list -->
    <div class="space-y-2">
      <div v-if="filteredCalls.length === 0" class="text-sm text-muted-foreground py-8 text-center">No calls match the filter</div>
      <div
        v-for="call in filteredCalls"
        :key="call.id"
        class="flex items-center gap-4 p-4 rounded-xl bg-card border border-border hover:border-border/80 transition-colors"
      >
        <!-- Priority indicator -->
        <div class="w-1 h-12 rounded-full shrink-0" :class="priorityBar(call.priority)" />

        <!-- Call info -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <p class="text-sm font-medium text-foreground truncate">{{ call.description || 'No description' }}</p>
            <span class="text-[10px] px-1.5 py-0.5 rounded border font-medium uppercase" :class="priorityBadge(call.priority)">
              {{ call.priority }}
            </span>
          </div>
          <p class="text-xs text-muted-foreground mt-0.5">
            <MapPin class="w-3 h-3 inline mr-1" />{{ call.location || 'Unknown' }}
            <span class="mx-2">·</span>
            <Phone class="w-3 h-3 inline mr-1" />{{ call.caller || 'Anonymous' }}
          </p>
        </div>

        <!-- Status -->
        <span class="text-xs px-2 py-1 rounded-lg border capitalize"
          :class="statusClass(call.status)"
        >{{ call.status }}</span>

        <!-- Actions -->
        <div class="flex items-center gap-1">
          <button
            v-if="call.status === 'pending'"
            title="Assign to me"
            class="w-8 h-8 rounded-lg flex items-center justify-center text-muted-foreground hover:text-primary hover:bg-primary/10 transition-colors"
            @click="assignToMe(call.id)"
          >
            <UserPlus class="w-4 h-4" />
          </button>
          <button
            v-if="call.status !== 'closed'"
            title="Close call"
            class="w-8 h-8 rounded-lg flex items-center justify-center text-muted-foreground hover:text-destructive-foreground hover:bg-destructive/10 transition-colors"
            @click="closeCall(call.id)"
          >
            <X class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>

    <!-- Create call modal -->
    <Teleport to="body">
      <Transition name="fade">
        <div v-if="showCreate" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50" @click.self="showCreate = false">
          <div class="w-full max-w-md rounded-xl bg-card border border-border p-6 space-y-4">
            <h3 class="text-base font-semibold text-foreground">Create Dispatch Call</h3>
            <input v-model="form.caller" placeholder="Caller" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <input v-model="form.location" placeholder="Location" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground" />
            <textarea v-model="form.description" placeholder="Description" rows="3" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground resize-none" />
            <select v-model="form.priority" class="w-full text-sm bg-input border border-border rounded-lg px-3 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring">
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
              <option value="critical">Critical</option>
            </select>
            <div class="flex justify-end gap-2 pt-2">
              <button class="text-sm px-4 py-2 rounded-lg text-muted-foreground hover:text-foreground transition-colors" @click="showCreate = false">Cancel</button>
              <button
                class="text-sm px-4 py-2 rounded-lg bg-primary text-primary-foreground font-medium hover:bg-primary/90 transition-colors"
                :disabled="dispatchStore.loading"
                @click="submitCall"
              >Create</button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed, reactive } from 'vue'
import { MapPin, Phone, UserPlus, X } from 'lucide-vue-next'
import { useDispatchStore } from '@/stores/dispatchStore'
import { useAppStore } from '@/stores/appStore'

const dispatchStore = useDispatchStore()
const appStore = useAppStore()
const filter = ref('all')
const showCreate = ref(false)

const form = reactive({
  caller: '',
  location: '',
  description: '',
  priority: 'medium' as const,
})

const filteredCalls = computed(() => {
  if (filter.value === 'all') return dispatchStore.calls.filter(c => c.status !== 'closed')
  return dispatchStore.calls.filter(c => c.status === filter.value)
})

function priorityBar(p: string) {
  const map: Record<string, string> = { low: 'bg-green-500', medium: 'bg-yellow-500', high: 'bg-orange-500', critical: 'bg-red-500' }
  return map[p] ?? 'bg-gray-500'
}

function priorityBadge(p: string) {
  const map: Record<string, string> = {
    low: 'border-green-500/30 text-green-400',
    medium: 'border-yellow-500/30 text-yellow-400',
    high: 'border-orange-500/30 text-orange-400',
    critical: 'border-red-500/30 text-red-400',
  }
  return map[p] ?? 'border-gray-500/30 text-gray-400'
}

function statusClass(s: string) {
  const map: Record<string, string> = {
    pending: 'border-yellow-500/30 text-yellow-400 bg-yellow-500/5',
    assigned: 'border-blue-500/30 text-blue-400 bg-blue-500/5',
    'en-route': 'border-cyan-500/30 text-cyan-400 bg-cyan-500/5',
    'on-scene': 'border-green-500/30 text-green-400 bg-green-500/5',
    closed: 'border-gray-500/30 text-gray-400 bg-gray-500/5',
  }
  return map[s] ?? ''
}

async function assignToMe(callId: number) {
  await dispatchStore.assignCall(callId, 0) // 0 = self
}

async function closeCall(callId: number) {
  await dispatchStore.updateCallStatus(callId, 'closed')
}

async function submitCall() {
  await dispatchStore.createCall({ ...form })
  showCreate.value = false
  form.caller = ''
  form.location = ''
  form.description = ''
  form.priority = 'medium'
}
</script>
