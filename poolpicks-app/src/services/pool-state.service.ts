import { Injectable, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class PoolStateService {
  currentPoolId = signal<string | null>(null);
  refreshRequested = signal<number>(0);

  setCurrentPoolId(id: string | null): void {
    this.currentPoolId.set(id);
  }

  triggerRefresh(): void {
    this.refreshRequested.update(v => v + 1);
  }
}
