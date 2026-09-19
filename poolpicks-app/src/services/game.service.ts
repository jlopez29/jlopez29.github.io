








import { Injectable, signal, inject, computed } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Game, GameStatus } from '../models/game.model';
import { timeout } from 'rxjs/operators';
import { firstValueFrom, Subscription } from 'rxjs';
import { DataService } from './data.service';
import { PlayoffTeam } from '../models/playoff.model';

// Interface for the relevant parts of the ESPN Scoreboard API response
interface EspnEvent {
  id: string;
  date: string;
  name: string;
  competitions: {
    competitors: {
      homeAway: 'home' | 'away';
      team: { displayName: string; };
      score?: string;
    }[];
    status: { type: { name: string; }; };
    odds?: { details: string; }[];
  }[];
}

interface EspnScoreboardResponse {
  season: { year: number };
  week: { number: number };
  events: EspnEvent[];
}

// Interfaces for ESPN Standings API
interface EspnStandingStat {
  name: string;
  value: number;
  abbreviation?: string;
}

interface EspnStandingEntry {
  team: {
    displayName: string;
  };
  stats: EspnStandingStat[];
}

interface EspnDivision {
  name: string;
  standings: {
    entries: EspnStandingEntry[];
  };
}

interface EspnConference {
  name: string;
  children: EspnDivision[];
}

interface EspnStandingsResponse {
  children: EspnConference[];
}

@Injectable({ providedIn: 'root' })
export class GameService {
  private scheduleRequest?: Subscription;
  private requestedUrl: string | null = null;
  private readonly weekRequests = new Map<string, Promise<Game[]>>();
  private readonly finalWeeks = new Map<string, Game[]>();
  // FIX: Explicitly type injected HttpClient to work around a type inference issue where it was being resolved as 'unknown'.
  private http: HttpClient = inject(HttpClient);
  private dataService: DataService = inject(DataService);
  
  public readonly LAST_REGULAR_SEASON_WEEK = 18;

  week = signal(0);
  year = signal(0);
  games = signal<Game[]>([]);
  gamesWeek = signal<number | null>(null); // Week corresponding to the `games` signal
  gamesYear = signal<number | null>(null);
  isLoading = signal<boolean>(true);
  isLoadingPlayoffPicture = signal<boolean>(false);
  isRegularSeasonOver = signal(false);
  createPoolOverride = signal(false);
  isCheckingOverride = signal(true);

  // FIX: Add stubbed playoffTeams signal to resolve compilation errors in PlayoffBracketComponent.
  playoffTeams = signal<{ afc: PlayoffTeam[], nfc: PlayoffTeam[] } | null>(null);

  isPlayoffs = computed(() => this.week() > this.LAST_REGULAR_SEASON_WEEK);

  constructor() {
    this.loadCurrentWeek();
    this.checkCreatePoolOverride();
  }

  loadCurrentWeek(): void {
    const url = `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard`;
    this.fetchGamesData(url, { isInitialLoad: true });
  }

  loadSpecificWeek(week: number, year = this.year()): void {
    if (year === 0) {
      console.error("Cannot load specific week before year is initialized.");
      return;
    }
    // During playoffs, the seasontype changes to 3.
    const seasontype = week > this.LAST_REGULAR_SEASON_WEEK ? 3 : 2;
    // The week number resets for playoffs (e.g., WC weekend is week 1 of seasontype 3)
    const apiWeek = week > this.LAST_REGULAR_SEASON_WEEK ? week - this.LAST_REGULAR_SEASON_WEEK : week;

    const url = `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?week=${apiWeek}&year=${year}&seasontype=${seasontype}`;
    this.fetchGamesData(url, { weekToLoad: week, yearToLoad: year });
  }

  /** Fetch a deadline/history schedule without changing the week visible on screen. */
  getWeekGames(week: number, year: number): Promise<Game[]> {
    const seasonType = week > this.LAST_REGULAR_SEASON_WEEK ? 3 : 2;
    const apiWeek = seasonType === 3 ? week - this.LAST_REGULAR_SEASON_WEEK : week;
    const url = `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?week=${apiWeek}&year=${year}&seasontype=${seasonType}`;
    const cached = this.finalWeeks.get(url);
    if (cached) return Promise.resolve(cached);
    const existing = this.weekRequests.get(url);
    if (existing) return existing;
    const request = firstValueFrom(this.http.get<EspnScoreboardResponse>(url).pipe(timeout(10000)))
      .then(data => {
        const games = this.mapEspnToGames(data.events);
        if (games.length && games.every(game => game.status === 'final')) this.finalWeeks.set(url, games);
        return games;
      })
      .finally(() => this.weekRequests.delete(url));
    this.weekRequests.set(url, request);
    return request;
  }

  loadPlayoffPicture(): void {
    const year = this.year();
    if (year === 0) {
      console.error("Cannot load playoff picture before year is initialized.");
      this.playoffTeams.set(null);
      return;
    }
    this.isLoadingPlayoffPicture.set(true);
    const url = `https://site.web.api.espn.com/apis/v2/sports/football/nfl/standings?level=3&season=${year}&seasontype=2&type=0`;
    this.http.get<EspnStandingsResponse>(url).pipe(
      timeout(10000), // 10 second timeout
    ).subscribe({
      next: (data) => {
        const afcTeams: PlayoffTeam[] = [];
        const nfcTeams: PlayoffTeam[] = [];

        const conferences = data.children || [];
        const afcConference = conferences.find(c => c.name === 'American Football Conference');
        const nfcConference = conferences.find(c => c.name === 'National Football Conference');

        if (afcConference && afcConference.children) {
          for (const division of afcConference.children) {
            const entries = division.standings?.entries ?? [];
            entries.forEach(entry => {
              const stats = entry.stats || [];
              const seedStat = stats.find(s => s.name === 'playoffSeed');
              
              // A team is in the playoffs if they have a conference seed between 1 and 7.
              if (seedStat && seedStat.value > 0 && seedStat.value <= 7) {
                afcTeams.push({
                  seed: seedStat.value,
                  teamName: entry.team.displayName,
                });
              }
            });
          }
        }

        if (nfcConference && nfcConference.children) {
           for (const division of nfcConference.children) {
            const entries = division.standings?.entries ?? [];
            entries.forEach(entry => {
              const stats = entry.stats || [];
              const seedStat = stats.find(s => s.name === 'playoffSeed');

              if (seedStat && seedStat.value > 0 && seedStat.value <= 7) {
                nfcTeams.push({
                  seed: seedStat.value,
                  teamName: entry.team.displayName,
                });
              }
            });
          }
        }
        
        // Handle case where playoff picture is not yet finalized and API returns partial or no seeds
        if (afcTeams.length < 7 || nfcTeams.length < 7) {
            console.warn('Playoff picture is not fully set. Some teams may be missing seeds.');
        }

        this.playoffTeams.set({
          afc: afcTeams.sort((a, b) => a.seed - b.seed),
          nfc: nfcTeams.sort((a, b) => a.seed - b.seed),
        });
        this.isLoadingPlayoffPicture.set(false);
      },
      error: (err) => {
        console.error('Failed to fetch playoff picture from ESPN API', err);
        // Set to null to indicate failure, allowing the UI to show an error message.
        this.playoffTeams.set(null);
        this.isLoadingPlayoffPicture.set(false);
      }
    });
  }
  
  private async checkCreatePoolOverride() {
    this.isCheckingOverride.set(true);
    try {
      this.createPoolOverride.set(await this.dataService.getCreatePoolOverride());
    } finally {
      this.isCheckingOverride.set(false);
    }
  }

  private fetchGamesData(url: string, options: { isInitialLoad?: boolean, weekToLoad?: number, yearToLoad?: number } = {}): void {
    if (this.requestedUrl === url && this.isLoading()) return;
    this.scheduleRequest?.unsubscribe();
    this.requestedUrl = url;
    this.isLoading.set(true);

    const requestedWeek = options.weekToLoad ?? (options.isInitialLoad ? undefined : this.week());

    // Reset the end-of-season flag if we are fetching a week within the regular season.
    if (requestedWeek && requestedWeek <= this.LAST_REGULAR_SEASON_WEEK) {
      this.isRegularSeasonOver.set(false);
    }
    
    this.scheduleRequest = this.http.get<EspnScoreboardResponse>(url).pipe(
      timeout(10000), // 10 second timeout
    ).subscribe({
      next: (data) => {
        if (options.isInitialLoad && data.week && data.season) {
          // The API week number resets for playoffs, so we need to adjust it to be sequential.
          const isPlayoffWeek = (data as any).season.type === 3;
          const actualWeek = isPlayoffWeek ? data.week.number + this.LAST_REGULAR_SEASON_WEEK : data.week.number;
          
          this.week.set(actualWeek);
          this.year.set(data.season.year);
          this.gamesWeek.set(actualWeek);
          this.gamesYear.set(data.season.year);

        } else if (options.weekToLoad) {
          this.gamesWeek.set(options.weekToLoad);
          this.gamesYear.set(options.yearToLoad ?? this.year());
        }

        // If we requested a week beyond the regular season and got no games, set the flag.
        if (requestedWeek && requestedWeek > this.LAST_REGULAR_SEASON_WEEK && (!data.events || data.events.length === 0)) {
            this.isRegularSeasonOver.set(true);
        }
        
        const mappedGames = this.mapEspnToGames(data.events);
        this.games.set(mappedGames);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Failed to fetch game schedule from ESPN API', err);

        // Keep the anonymous Firebase identity intact when the schedule API is unavailable.
        if (options.isInitialLoad) {
          this.dataService.logError('GameService.fetchGamesData.initialLoad', {
            error: err.name === 'TimeoutError' ? 'Request timed out after 10 seconds' : (err.message || String(err)),
            url
          });
        }

        // If a non-critical request fails (e.g., for a historical week),
        // just update gamesWeek to signal the UI that the loading attempt is over.
        // This prevents an infinite loading state while allowing the user to stay in the app.
        if (options.weekToLoad) {
          this.gamesWeek.set(options.weekToLoad);
          this.gamesYear.set(options.yearToLoad ?? this.year());
        }
        this.games.set([]);
        this.isLoading.set(false);
      }
    });
  }

  private mapEspnToGames(events: EspnEvent[]): Game[] {
    if (!events) return [];

    // Sort events by date to ensure chronological order for tiebreaker logic.
    const sortedEvents = [...events].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

    const mondayEvents = sortedEvents
        .filter(e => new Intl.DateTimeFormat('en-US', { weekday: 'short', timeZone: 'America/New_York' }).format(new Date(e.date)) === 'Mon')
        .sort((a,b) => new Date(b.date).getTime() - new Date(a.date).getTime());
    
    // There may not be a Monday night game in the playoffs, so this logic remains flexible.
    const finalGameOfTheWeekId = sortedEvents.length > 0 ? sortedEvents[sortedEvents.length - 1].id : null;
    const tiebreakerGameId = mondayEvents.length > 0 ? mondayEvents[0].id : finalGameOfTheWeekId;

    return sortedEvents.map(event => {
      // FIX: Add defensive check for event.competitions to prevent crashes if an event has no competition data.
      if (!event.competitions || event.competitions.length === 0) {
        return null;
      }
      const competition = event.competitions[0];
       // FIX: Also check for competition.competitors to handle cases where the competition object is present but empty.
      if (!competition.competitors) {
        return null;
      }
      const homeComp = competition.competitors.find(c => c.homeAway === 'home');
      const awayComp = competition.competitors.find(c => c.homeAway === 'away');
      
      if (!homeComp || !awayComp) {
        // This can happen for non-standard events. Filter them out.
        return null;
      }

      const homeScore = parseInt(homeComp.score || '0', 10);
      const awayScore = parseInt(awayComp.score || '0', 10);
      const status = this.mapEspnStatus(competition.status.type.name);
      
      let winner: string | null = null;
      if (status === 'final') {
        if (homeScore > awayScore) {
          winner = homeComp.team.displayName;
        } else if (awayScore > homeScore) {
          winner = awayComp.team.displayName;
        }
      }
      
      return {
        id: parseInt(event.id, 10),
        homeTeam: homeComp.team.displayName,
        awayTeam: awayComp.team.displayName,
        homeScore,
        awayScore,
        status,
        time: this.formatGameTime(new Date(event.date)),
        startTime: event.date,
        isMondayNight: event.id === tiebreakerGameId, // Use the more robust tiebreaker game ID
        winner,
        line: competition.odds?.[0]?.details,
      };
    // FIX: The type predicate `(g): g is Game` was causing a compilation error.
    // It has been replaced with a simple filter and a type assertion to resolve the type inference issue.
    }).filter(g => g !== null) as Game[];
  }

  private mapEspnStatus(espnStatus: string): GameStatus {
    switch (espnStatus) {
      case 'STATUS_FINAL':
      case 'STATUS_END_OF_GAME':
        return 'final';
      case 'STATUS_IN_PROGRESS':
      case 'STATUS_HALFTIME':
      case 'STATUS_FIRST_QUARTER':
      case 'STATUS_SECOND_QUARTER':
      case 'STATUS_THIRD_QUARTER':
      case 'STATUS_FOURTH_QUARTER':
      case 'STATUS_OVERTIME':
      case 'STATUS_END_PERIOD':
        return 'in_progress';
      case 'STATUS_SCHEDULED':
      case 'STATUS_POSTPONED':
      case 'STATUS_CANCELED':
      default:
        return 'scheduled';
    }
  }

  private formatGameTime(date: Date): string {
    const options: Intl.DateTimeFormatOptions = {
      weekday: 'short',
      hour: 'numeric',
      minute: 'numeric',
      hour12: true,
      timeZone: 'America/New_York'
    };
    return date.toLocaleString('en-US', options).replace(',', '') + ' ET';
  }
}
