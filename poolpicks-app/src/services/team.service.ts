
import { Injectable, signal, computed } from '@angular/core';
import { Game } from '../models/game.model';

export interface Team {
  name: string;
  abbr: string;
  logo: string;
  primaryColor: string;
  secondaryColor: string;
}

@Injectable({ providedIn: 'root' })
export class TeamService {
  private teamsByName = signal<Map<string, Team>>(new Map([
    // AFC East
    ['Buffalo Bills', { name: 'Buffalo Bills', abbr: 'BUF', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/buf.png', primaryColor: '#00338D', secondaryColor: '#C60C30' }],
    ['Miami Dolphins', { name: 'Miami Dolphins', abbr: 'MIA', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/mia.png', primaryColor: '#008E97', secondaryColor: '#FC4C02' }],
    ['New England Patriots', { name: 'New England Patriots', abbr: 'NE', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/ne.png', primaryColor: '#002244', secondaryColor: '#C60C30' }],
    ['New York Jets', { name: 'New York Jets', abbr: 'NYJ', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/nyj.png', primaryColor: '#125740', secondaryColor: '#FFFFFF' }],
    // AFC North
    ['Baltimore Ravens', { name: 'Baltimore Ravens', abbr: 'BAL', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/bal.png', primaryColor: '#241773', secondaryColor: '#9E7C0C' }],
    ['Cincinnati Bengals', { name: 'Cincinnati Bengals', abbr: 'CIN', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/cin.png', primaryColor: '#FB4F14', secondaryColor: '#000000' }],
    ['Cleveland Browns', { name: 'Cleveland Browns', abbr: 'CLE', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/cle.png', primaryColor: '#311D00', secondaryColor: '#FF3C00' }],
    ['Pittsburgh Steelers', { name: 'Pittsburgh Steelers', abbr: 'PIT', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/pit.png', primaryColor: '#FFB612', secondaryColor: '#101820' }],
    // AFC South
    ['Houston Texans', { name: 'Houston Texans', abbr: 'HOU', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/hou.png', primaryColor: '#03202F', secondaryColor: '#A71930' }],
    ['Indianapolis Colts', { name: 'Indianapolis Colts', abbr: 'IND', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/ind.png', primaryColor: '#002C5F', secondaryColor: '#A2AAAD' }],
    ['Jacksonville Jaguars', { name: 'Jacksonville Jaguars', abbr: 'JAX', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/jax.png', primaryColor: '#006778', secondaryColor: '#D7A22A' }],
    ['Tennessee Titans', { name: 'Tennessee Titans', abbr: 'TEN', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/ten.png', primaryColor: '#0C2340', secondaryColor: '#4B92DB' }],
    // AFC West
    ['Denver Broncos', { name: 'Denver Broncos', abbr: 'DEN', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/den.png', primaryColor: '#FB4F14', secondaryColor: '#002244' }],
    ['Kansas City Chiefs', { name: 'Kansas City Chiefs', abbr: 'KC', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/kc.png', primaryColor: '#E31837', secondaryColor: '#FFB81C' }],
    ['Las Vegas Raiders', { name: 'Las Vegas Raiders', abbr: 'LV', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/lv.png', primaryColor: '#000000', secondaryColor: '#A5ACAF' }],
    ['Los Angeles Chargers', { name: 'Los Angeles Chargers', abbr: 'LAC', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/lac.png', primaryColor: '#0080C6', secondaryColor: '#FFC20E' }],
    // NFC East
    ['Dallas Cowboys', { name: 'Dallas Cowboys', abbr: 'DAL', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/dal.png', primaryColor: '#041E42', secondaryColor: '#869397' }],
    ['New York Giants', { name: 'New York Giants', abbr: 'NYG', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/nyg.png', primaryColor: '#0B2265', secondaryColor: '#A71930' }],
    ['Philadelphia Eagles', { name: 'Philadelphia Eagles', abbr: 'PHI', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/phi.png', primaryColor: '#004C54', secondaryColor: '#A5ACAF' }],
    ['Washington Commanders', { name: 'Washington Commanders', abbr: 'WSH', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/wsh.png', primaryColor: '#5A1414', secondaryColor: '#FFB612' }],
    // NFC North
    ['Chicago Bears', { name: 'Chicago Bears', abbr: 'CHI', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/chi.png', primaryColor: '#0B162A', secondaryColor: '#C83803' }],
    ['Detroit Lions', { name: 'Detroit Lions', abbr: 'DET', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/det.png', primaryColor: '#0076B6', secondaryColor: '#B0B7BC' }],
    ['Green Bay Packers', { name: 'Green Bay Packers', abbr: 'GB', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/gb.png', primaryColor: '#203731', secondaryColor: '#FFB612' }],
    ['Minnesota Vikings', { name: 'Minnesota Vikings', abbr: 'MIN', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/min.png', primaryColor: '#4F2683', secondaryColor: '#FFC62F' }],
    // NFC South
    ['Atlanta Falcons', { name: 'Atlanta Falcons', abbr: 'ATL', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/atl.png', primaryColor: '#A71930', secondaryColor: '#000000' }],
    ['Carolina Panthers', { name: 'Carolina Panthers', abbr: 'CAR', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/car.png', primaryColor: '#0085CA', secondaryColor: '#101820' }],
    ['New Orleans Saints', { name: 'New Orleans Saints', abbr: 'NO', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/no.png', primaryColor: '#D3BC8D', secondaryColor: '#101820' }],
    ['Tampa Bay Buccaneers', { name: 'Tampa Bay Buccaneers', abbr: 'TB', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/tb.png', primaryColor: '#D50A0A', secondaryColor: '#343434' }],
    // NFC West
    ['Arizona Cardinals', { name: 'Arizona Cardinals', abbr: 'ARI', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/ari.png', primaryColor: '#97233F', secondaryColor: '#000000' }],
    ['Los Angeles Rams', { name: 'Los Angeles Rams', abbr: 'LAR', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/lar.png', primaryColor: '#003594', secondaryColor: '#FFD100' }],
    ['San Francisco 49ers', { name: 'San Francisco 49ers', abbr: 'SF', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/sf.png', primaryColor: '#AA0000', secondaryColor: '#B3995D' }],
    ['Seattle Seahawks', { name: 'Seattle Seahawks', abbr: 'SEA', logo: 'https://a.espncdn.com/i/teamlogos/nfl/500/sea.png', primaryColor: '#002244', secondaryColor: '#69BE28' }],
  ]));

  private teamsByAbbr = computed(() => {
    const map = new Map<string, Team>();
    for (const team of this.teamsByName().values()) {
      map.set(team.abbr, team);
    }
    return map;
  });

  getTeamByName(name: string): Team | undefined {
    return this.teamsByName().get(name);
  }

  getTeamByAbbr(abbr: string): Team | undefined {
    return this.teamsByAbbr().get(abbr);
  }

  getUnderdog(game: Game): string | null {
    if (!game.line || game.line.toUpperCase() === 'EVEN') return null;

    const parts = game.line.split(' ');
    if (parts.length < 2) return null;
    
    const abbr = parts[0];
    const spread = parseFloat(parts[1]);

    if (isNaN(spread)) return null;

    const teamFromLine = this.getTeamByAbbr(abbr);
    if (!teamFromLine) {
        // This log is helpful for debugging data mismatches from the API
        console.warn(`Could not find team with abbreviation: ${abbr} from line: ${game.line}`);
        return null;
    }

    // Team with a positive spread (e.g., +7.5) is the underdog.
    if (spread > 0) {
        return teamFromLine.name;
    }
    
    // Team with a negative spread (e.g., -7.5) is the favorite, so the other team is the underdog.
    if (game.homeTeam === teamFromLine.name) {
        return game.awayTeam;
    } else if (game.awayTeam === teamFromLine.name) {
        return game.homeTeam;
    } else {
        // This case indicates a name mismatch between ESPN's display name and our team list.
        console.warn(`Team name mismatch for ${teamFromLine.name}. Home: ${game.homeTeam}, Away: ${game.awayTeam}`);
        return null;
    }
  }
}
