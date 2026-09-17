
export interface PlayoffTeam {
  seed: number;
  teamName: string;
}

export interface PlayoffPicks {
  confidencePicks: { [teamName: string]: number }; // key: teamName, value: confidence
}
