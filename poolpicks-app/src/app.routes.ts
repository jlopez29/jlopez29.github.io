import { Routes } from '@angular/router';
import { HomeComponent } from './components/home/home.component';
import { PoolComponent } from './components/pool/pool.component';
import { ParticipantPicksComponent } from './components/participant-picks/participant-picks.component';
import { PlayerStatsComponent } from './components/player-stats/player-stats.component';
import { TrophyCaseComponent } from './components/trophy-case/trophy-case.component';

export const APP_ROUTES: Routes = [
  { path: '', component: HomeComponent, pathMatch: 'full' },
  { path: 'trophies', component: TrophyCaseComponent },
  { path: 'pool/:id', component: PoolComponent },
  { path: 'pool/:id/picks/:name', component: ParticipantPicksComponent },
  { path: 'pool/:id/stats/:name', component: PlayerStatsComponent },
  { path: '**', redirectTo: '' } // Redirect to home for any other route
];
