export function Icon({ name, size = 22 }: { name: string; size?: number }) {
  const paths: Record<string, React.ReactNode> = {
    wood: (
      <>
        <path d="M5 8h14v11H5z" fill="#c6a16e" />
        <ellipse cx="5" cy="13.5" rx="3" ry="5.5" fill="#ecd2a0" />
        <path d="M9 10h8m-7 4h8m-7 3h6" />
      </>
    ),
    stone: (
      <path
        d="m3 17 3-10 8-3 7 9-4 7H7z m3-10 7 4 8 2m-8-2 4 9"
        fill="#bdc4b0"
      />
    ),
    water: (
      <path d="M12 2S4 11 4 16a8 8 0 0 0 16 0c0-5-8-14-8-14Z" fill="#a7d3d8" />
    ),
    food: (
      <>
        <path d="M12 22V6m0 4L6 6m6 8 6-4m-6 8-6-4" />
        <ellipse
          cx="6"
          cy="6"
          rx="3"
          ry="5"
          fill="#dec47d"
          transform="rotate(-40 6 6)"
        />
        <ellipse
          cx="18"
          cy="10"
          rx="3"
          ry="5"
          fill="#dec47d"
          transform="rotate(40 18 10)"
        />
      </>
    ),
    rain: (
      <>
        <path d="M6 14a4 4 0 0 1 0-8 6 6 0 0 1 11-1 4.5 4.5 0 0 1 1 9" />
        <path d="m8 17-1 3m6-3-1 3m6-3-1 3" />
      </>
    ),
    sun: (
      <>
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5" />
      </>
    ),
    raise: (
      <>
        <path d="m2 20 7-10 4 5 3-4 6 9M12 2v7m-3-3 3-3 3 3" />
      </>
    ),
    lower: (
      <>
        <path d="m2 11 6 9h8l6-9M12 2v9m-3-3 3 3 3-3" />
      </>
    ),
    smooth: (
      <>
        <path d="M2 18h20M4 11l4-5 5 5h7M8 2v4m8 0v5" />
      </>
    ),
    lightning: <path d="m14 2-9 12h6l-1 8 9-12h-6z" />,
    fire: (
      <path d="M12 2c0 7-6 6-6 13a6 6 0 0 0 12 0c0-3-2-5-3-7 0 5-3 5-3 5s3-5 0-11Z" />
    ),
    heart: <path d="M12 21 3 12C-2 5 7 0 12 7 17 0 26 5 21 12Z" />,
    hand: (
      <>
        <path d="M8 12V5a2 2 0 0 1 4 0v6-8a2 2 0 0 1 4 0v8-5a2 2 0 0 1 4 0v10c0 5-10 8-13 3L3 13c-2-3 1-5 3-2l2 2" />
      </>
    ),
    leaf: (
      <>
        <path d="M20 3C7 1-1 14 9 18S24 10 20 3ZM4 22 17 8" />
      </>
    ),
    coin: (
      <>
        <ellipse cx="12" cy="12" rx="8" ry="9" />
        <path d="M12 7v10m3-9c-6-3-8 5-2 4s5 7-2 4" />
      </>
    ),
    spark: (
      <>
        <path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5Z" />
      </>
    ),
    people: (
      <>
        <circle cx="9" cy="7" r="3" />
        <path d="M3 21v-5a6 6 0 0 1 12 0v5m3-17a3 3 0 0 1 0 6m1 3a5 5 0 0 1 3 5v3" />
      </>
    ),
    build: (
      <>
        <path d="m2 10 10-8 10 8M5 8v13h14V8M10 21v-8h5v8" />
      </>
    ),
    book: (
      <>
        <path d="M12 5c-4-3-8-2-10-1v16c4-2 7-1 10 1 3-2 6-3 10-1V4c-3-1-6-2-10 1Zm0 0v16" />
      </>
    ),
    settings: (
      <>
        <path d="m9 3 1-2h4l1 2 3 2 3 1v4l-2 2 2 2v4l-3 1-3 2-1 2h-4l-1-2-3-2-3-1v-4l2-2-2-2V6l3-1Z" />
        <circle cx="12" cy="12" r="3" />
      </>
    ),
    globe: (
      <>
        <circle cx="12" cy="12" r="9" />
        <ellipse cx="12" cy="12" rx="4" ry="9" />
        <path d="M3 12h18" />
      </>
    ),
    camera: (
      <>
        <path d="M2 7h5l2-3h6l2 3h5v14H2Z" />
        <circle cx="12" cy="13" r="4" />
      </>
    ),
    pause: (
      <>
        <path d="M8 4v16M16 4v16" />
      </>
    ),
    play: <path d="m7 3 14 9-14 9Z" />,
    lock: (
      <>
        <rect x="5" y="10" width="14" height="11" rx="2" />
        <path d="M8 10V6a4 4 0 0 1 8 0v4m-4 5v2" />
      </>
    ),
    chevron: <path d="m9 5 7 7-7 7" />,
    close: <path d="m5 5 14 14M5 19 19 5" />,
    check: <path d="m4 12 5 5L21 5" />,
    back: <path d="m9 5-7 7 7 7M2 12h20" />,
    help: (
      <>
        <circle cx="12" cy="12" r="10" />
        <path d="M9 8c0-4 7-4 7 0 0 3-4 3-4 6m0 3v1" />
      </>
    ),
    volume: (
      <>
        <path d="M2 9h4l5-5v16l-5-5H2Zm13-1a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14" />
      </>
    ),
    mute: (
      <>
        <path d="M2 9h4l5-5v16l-5-5H2Zm14 0 6 6m-6 0 6-6" />
      </>
    ),
  };
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.65"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name] || paths.spark}
    </svg>
  );
}
