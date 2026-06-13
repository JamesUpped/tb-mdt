<template>
  <div class="space-y-4">
    <!-- Search bar -->
    <div class="flex items-center gap-3">
      <div class="relative flex-1">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input
          v-model="query"
          placeholder="Search by plate number..."
          class="w-full text-sm bg-input border border-border rounded-lg pl-10 pr-4 py-2 text-foreground outline-none focus:ring-1 focus:ring-ring placeholder:text-muted-foreground"
          @keydown.enter="doSearch"
        />
      </div>
      <button
        class="text-sm bg-primary text-primary-foreground px-4 py-2 rounded-lg font-medium hover:bg-primary/90 transition-colors"
        :disabled="vehicleStore.loading"
        @click="doSearch"
      >Search</button>
    </div>

    <!-- Results list -->
    <div v-if="vehicleStore.results.length > 0 && !vehicleStore.activeVehicle" class="space-y-2">
      <div
        v-for="v in vehicleStore.results"
        :key="v.id"
        class="flex items-center gap-4 p-4 rounded-xl bg-card border border-border hover:border-primary/30 cursor-pointer transition-colors"
        @click="vehicleStore.loadProfile(v.plate)"
      >
        <div class="w-10 h-10 rounded-full bg-secondary flex items-center justify-center">
          <Car class="w-5 h-5 text-muted-foreground" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-foreground font-mono">{{ v.plate }}</p>
          <p class="text-xs text-muted-foreground">{{ v.model }} · Owner: {{ v.owner }}</p>
        </div>
        <ChevronRight class="w-4 h-4 text-muted-foreground" />
      </div>
    </div>

    <!-- Vehicle profile -->
    <div v-if="vehicleStore.activeVehicle" class="space-y-4">
      <div class="flex items-center justify-between">
        <button class="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1 transition-colors" @click="vehicleStore.clearProfile()">
          <ArrowLeft class="w-3 h-3" /> Back to results
        </button>
        <button
          v-if="appStore.can('vehicles', 'flag')"
          class="text-xs px-3 py-1.5 rounded-lg font-medium transition-colors flex items-center gap-1.5 border"
          :class="vehicle.stolen
            ? 'bg-green-500/15 text-green-400 border-green-500/30 hover:bg-green-500/25'
            : 'bg-red-500/15 text-red-400 border-red-500/30 hover:bg-red-500/25'"
          @click="toggleStolen"
        >
          <ShieldAlert class="w-3.5 h-3.5" />
          {{ vehicle.stolen ? 'Clear Stolen Flag' : 'Flag as Stolen' }}
        </button>
      </div>

      <!-- Stolen banner -->
      <div v-if="vehicle.stolen" class="flex items-center gap-3 p-3 rounded-xl bg-red-500/10 border border-red-500/40">
        <ShieldAlert class="w-5 h-5 text-red-400 shrink-0" />
        <div>
          <p class="text-sm font-semibold text-red-400">VEHICLE REPORTED STOLEN</p>
          <p v-if="vehicle.flagNotes" class="text-xs text-red-400/80">{{ vehicle.flagNotes }}</p>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-4">
        <!-- Vehicle info -->
        <div class="col-span-1 rounded-xl bg-card border border-border p-4 space-y-3">
          <div class="w-16 h-16 mx-auto rounded-full bg-secondary flex items-center justify-center">
            <Car class="w-8 h-8 text-muted-foreground" />
          </div>
          <div class="text-center">
            <p class="text-lg font-bold text-foreground font-mono">{{ vehicle.plate }}</p>
            <p class="text-xs text-muted-foreground">{{ vehicle.model }}</p>
          </div>
          <div class="space-y-2 text-xs">
            <InfoRow label="Owner" :value="vehicle.owner" />
            <InfoRow label="Owner ID" :value="vehicle.ownerCitizenid" />
            <InfoRow label="Color" :value="vehicle.color || 'Unknown'" />
          </div>
        </div>

        <!-- BOLOs and incidents -->
        <div class="col-span-2 rounded-xl bg-card border border-border p-4">
          <div class="flex gap-2 border-b border-border pb-2 mb-3">
            <button
              v-for="tab in tabs"
              :key="tab"
              class="text-xs px-3 py-1.5 rounded-lg transition-colors capitalize"
              :class="activeTab === tab ? 'bg-primary/10 text-primary font-medium' : 'text-muted-foreground hover:text-foreground'"
              @click="activeTab = tab"
            >{{ tab }}</button>
          </div>

          <div v-if="activeTab === 'bolos'" class="space-y-2 max-h-[350px] overflow-auto">
            <div v-if="!vehicle.bolos?.length" class="text-sm text-muted-foreground text-center py-4">No active BOLOs</div>
            <div v-for="b in vehicle.bolos" :key="b.id" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
              <AlertTriangle class="w-4 h-4 text-amber-400 shrink-0" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-foreground truncate">{{ b.reason }}</p>
                <p class="text-xs text-muted-foreground">{{ b.status }} · {{ b.createdAt }}</p>
              </div>
            </div>
          </div>

          <div v-if="activeTab === 'incidents'" class="space-y-2 max-h-[350px] overflow-auto">
            <div v-if="!vehicle.incidents?.length" class="text-sm text-muted-foreground text-center py-4">No linked incidents</div>
            <div v-for="i in vehicle.incidents" :key="i.id" class="flex items-center gap-3 p-3 rounded-lg bg-secondary/40 border border-border/50">
              <FileText class="w-4 h-4 text-muted-foreground shrink-0" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-foreground truncate">{{ i.title }}</p>
                <p class="text-xs text-muted-foreground">Case #{{ i.caseNumber }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Empty state -->
    <div v-if="vehicleStore.results.length === 0 && !vehicleStore.activeVehicle && !vehicleStore.loading" class="text-center py-12">
      <Car class="w-12 h-12 text-muted-foreground/30 mx-auto mb-3" />
      <p class="text-sm text-muted-foreground">Search for a vehicle by plate number</p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed } from 'vue'
import { Search, Car, ChevronRight, ArrowLeft, AlertTriangle, FileText, ShieldAlert } from 'lucide-vue-next'
import { useVehicleStore } from '@/stores/vehicleStore'
import { useAppStore } from '@/stores/appStore'
import { fetchNui } from '@/composables/fetchNui'
import InfoRow from '@/components/ui/InfoRow.vue'

const vehicleStore = useVehicleStore()
const appStore = useAppStore()
const query = ref('')
const activeTab = ref<'bolos' | 'incidents'>('bolos')
const tabs = ['bolos', 'incidents'] as const

const vehicle = computed(() => vehicleStore.activeVehicle!)

function doSearch() {
  if (query.value.trim()) {
    vehicleStore.search(query.value.trim())
  }
}

async function toggleStolen() {
  const newState = !vehicle.value.stolen
  const result = await fetchNui<{ success: boolean }>('setVehicleFlags', {
    plate: vehicle.value.plate,
    stolen: newState,
    notes: vehicle.value.flagNotes ?? '',
  })
  if (result.success && vehicleStore.activeVehicle) {
    vehicleStore.activeVehicle.stolen = newState
  }
}
</script>
