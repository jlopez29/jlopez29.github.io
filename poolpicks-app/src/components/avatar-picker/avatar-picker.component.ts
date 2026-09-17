import { Component, ChangeDetectionStrategy, output, signal } from '@angular/core';
import { CommonModule } from '@angular/common';

const AVATAR_SVGS: string[] = [
  // Helmet
`<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="11" cy="10" r="6.5" fill="#64748b"/>
  <path d="M5 12h4.5a2 2 0 0 1 2 2v3h-2.5a3 3 0 0 1-3-3V12Z" fill="#94a3b8"/>
  <circle cx="11" cy="10" r="1.25" fill="#0f172a"/>
  <path d="M14 15h4.5a1.5 1.5 0 0 1 0 3H14v-3Z" fill="#e11d48"/>
  <path d="M14 16h3.25" stroke="#334155" stroke-width="1.25" stroke-linecap="round"/>
</svg>`
,
  // Football Field
`<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="2" y="3" width="20" height="18" rx="3" fill="#166534"/>
  <rect x="2" y="3" width="3" height="18" fill="#065f46"/>
  <rect x="19" y="3" width="3" height="18" fill="#065f46"/>
  <path d="M7 4v16M12 4v16M17 4v16" stroke="#ffffff" stroke-width="1" stroke-linecap="round" stroke-dasharray="1.5 2"/>
  <path d="M4 12h16" stroke="#ffffff" stroke-width="1"/>
</svg>`,
// Whistle
`<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M6.5 9.5h6.5a3.5 3.5 0 1 1 0 7H10a4.5 4.5 0 0 1-3.5-7Z" fill="#cbd5e1"/>
  <circle cx="15.5" cy="13" r="1.75" fill="#475569"/>
  <path d="M3 10.5h3v3.5H3a1.5 1.5 0 0 1 0-3Z" fill="#94a3b8"/>
  <circle cx="6" cy="12.25" r="1.25" fill="#64748b"/>
</svg>`
,
  // Foam Finger
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M11 3c.55 0 1 .45 1 1v5h5c.83 0 1.5.67 1.5 1.5V16c0 1.66-1.34 3-3 3H9.5c-1.66 0-3-1.34-3-3v-3.75H5
            C4.45 12.25 4 11.8 4 11.25v-1.5C4 9.2 4.45 8.75 5 8.75h1V7c0-2.21 1.79-4 4-4Z" fill="#16a34a"/>
    <path d="M12 4v5.5h5c.55 0 1 .45 1 1V16c0 1.1-.9 2-2 2H9.5c-1.1 0-2-.9-2-2v-4.75H5v-1h2V7c0-1.66 1.34-3 3-3h2Z"
          fill="#22c55e" fill-opacity=".55"/>
    <text x="12" y="16.5" font-family="Inter, Arial, sans-serif" font-size="6.5" fill="#ffffff" text-anchor="middle" font-weight="700">#1</text>
  </svg>`,
  // Hot Dog
`<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="10" width="18" height="6" rx="3" fill="#f59e0b"/>
  <rect x="4.5" y="9" width="15" height="8" rx="3" fill="#dc2626"/>
  <path d="M6 12c1 .5 2-.5 3 0s2 .5 3 0 2-.5 3 0 2 .5 3 0" stroke="#fde68a" stroke-width="1.4" stroke-linecap="round" fill="none"/>
</svg>`,
// Rocket
`<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 3c3.5 2.5 5.5 6.5 5.5 9.5a2 2 0 0 1-2 2h-1l-1.25 2H9.75L8.5 14.5H7.5a2 2 0 0 1-2-2C5.5 9.5 8.5 5.5 12 3Z" fill="#2563eb"/>
  <circle cx="12.75" cy="9.25" r="1.25" fill="#93c5fd"/>
  <path d="M9.5 16l-1 2.5c-.2.5.2 1 .75 1H14.75c.55 0 .95-.5.75-1L14.5 16H9.5Z" fill="#3b82f6"/>
  <path d="M11.25 19.5h1.5V21h-1.5v-1.5Z" fill="#93c5fd"/>
</svg>`,
// Football
`<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M4.5 12c0-1.5 1.4-3.4 3.7-5C10.5 5.3 13.4 4.5 15 4.5s3.4.8 6 3.5c2.7 2.6 2.7 5.9 0 8.5S17.6 20 15 20s-4.5-.8-6.8-2.5C5.9 15.9 4.5 13.7 4.5 12Z" fill="#92400e"/>
  <path d="M7.5 8.5c2.5 1.2 6.5 1.2 9 0" stroke="#fef3c7" stroke-width="1.2" stroke-linecap="round"/>
  <path d="M7.5 15.5c2.5-1.2 6.5-1.2 9 0" stroke="#fef3c7" stroke-width="1.2" stroke-linecap="round"/>
  <path d="M10 12h4" stroke="#fef3c7" stroke-width="1.2" stroke-linecap="round"/>
  <path d="M11 11v2M12 11v2M13 11v2" stroke="#fef3c7" stroke-width="1.1" stroke-linecap="round"/>
</svg>`
,
  // Trophy
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M17 2H7C6.45 2 6 2.45 6 3V4C6 4.55 6.45 5 7 5H17C17.55 5 18 4.55 18 4V3C18 2.45 17.55 2 17 2Z" fill="#f59e0b"/><path d="M18 6H6C4.34 6 3 7.34 3 9V13C3 14.66 4.34 16 6 16H7V18C7 19.1 7.9 20 9 20H15C16.1 20 17 19.1 17 18V16H18C19.66 16 21 14.66 21 13V9C21 7.34 19.66 6 18 6ZM19 13C19 13.55 18.55 14 18 14H17V10H19V13ZM7 10V14H6C5.45 14 5 13.55 5 13V9C5 8.45 5.45 8 6 8H7V10Z" fill="#fbbf24"/><path d="M9 20H15C16.1 20 17 19.1 17 18V16H7V18C7 19.1 7.9 20 9 20Z" fill="#f59e0b"/><path d="M15 20H9C7.9 20 7 19.1 7 18V16H17V18C17 19.1 16.1 20 15 20Z" fill="#f59e0b"/><path d="M12 20V22H15C15.55 22 16 21.55 16 21V20H12Z" fill="#d97706"/><path d="M12 22V20H9C8.45 20 8 20.45 8 21V22H12Z" fill="#d97706"/></svg>`,
  // Ghost
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 2C7.03 2 3 6.03 3 11V22H21V11C21 6.03 16.97 2 12 2Z" fill="#e5e7eb"/><path d="M17 22H19V11C19 7.13 15.87 4 12 4C8.13 4 5 7.13 5 11V22H7V19H9V22H11V18H13V22H15V19H17V22Z" fill="#f9fafb"/><path d="M9 12C8.17 12 7.5 11.33 7.5 10.5C7.5 9.67 8.17 9 9 9C9.83 9 10.5 9.67 10.5 10.5C10.5 11.33 9.83 12 9 12Z" fill="#1f2937"/><path d="M15 12C14.17 12 13.5 11.33 13.5 10.5C13.5 9.67 14.17 9 15 9C15.83 9 16.5 9.67 16.5 10.5C16.5 11.33 15.83 12 15 12Z" fill="#1f2937"/></svg>`,
  // Robot
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M18 4H6C4.9 4 4 4.9 4 6V16C4 17.1 4.9 18 6 18H18C19.1 18 20 17.1 20 16V6C20 4.9 19.1 4 18 4Z" fill="#9ca3af"/><path d="M18 18H6C4.9 18 4 17.1 4 16V6C4 4.9 4.9 4 6 4H18C19.1 4 20 4.9 20 6V16C20 17.1 19.1 18 18 18Z" fill="#9ca3af"/><path d="M16 2H8C7.45 2 7 2.45 7 3C7 3.55 7.45 4 8 4H16C16.55 4 17 3.55 17 3C17 2.45 16.55 2 16 2Z" fill="#6b7280"/><path d="M7 20H9V22H7V20Z" fill="#6b7280"/><path d="M15 20H17V22H15V20Z" fill="#6b7280"/><path d="M9 9H15V13H9V9Z" fill="#10b981"/><path d="M8 8H7C6.45 8 6 8.45 6 9C6 9.55 6.45 10 7 10H8V8Z" fill="#6b7280"/><path d="M17 8H16V10H17C17.55 10 18 9.55 18 9C18 8.45 17.55 8 17 8Z" fill="#6b7280"/><path d="M9 9H15V13H9V9Z" fill="#10b981"/><path d="M9.5 10C8.95 10 8.5 10.45 8.5 11C8.5 11.55 8.95 12 9.5 12C10.05 12 10.5 11.55 10.5 11C10.5 10.45 10.05 10 9.5 10Z" fill="#059669"/><path d="M14.5 10C13.95 10 13.5 10.45 13.5 11C13.5 11.55 13.95 12 14.5 12C15.05 12 15.5 11.55 15.5 11C15.5 10.45 15.05 10 14.5 10Z" fill="#059669"/></svg>`,
 // Cat
`<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 6l2.5 1.5L12 6l3.5 1.5L18 6c1.66 0 3 1.34 3 3v9c0 1.66-1.34 3-3 3H6c-1.66 0-3-1.34-3-3V9c0-1.66 1.34-3 3-3Z" fill="#fb923c"/>
  <circle cx="9" cy="12" r="1" fill="#0f172a"/>
  <circle cx="15" cy="12" r="1" fill="#0f172a"/>
  <path d="M9.5 14.5c1 .5 4 .5 5 0" stroke="#ffffff" stroke-width="1" stroke-linecap="round"/>
</svg>`
,
  // Lightning
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M11 21H10C9.4 21 9 20.6 9 20V13H6C5.4 13 5.2 12.3 5.6 12L13 3H14C14.6 3 15 3.4 15 4V11H18C18.6 11 18.8 11.7 18.4 12L11 21Z" fill="#facc15"/></svg>`,
  // Star
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 17.27L18.18 21L16.54 13.97L22 9.24L14.81 8.63L12 2L9.19 8.63L2 9.24L7.46 13.97L5.82 21L12 17.27Z" fill="#fde047"/></svg>`,
  // Target
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="10" fill="#ef4444"/><circle cx="12" cy="12" r="6" fill="#f9fafb"/><circle cx="12" cy="12" r="2" fill="#ef4444"/></svg>`,
  // Joystick
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M15 7H9V13H15V7Z" fill="#4b5563"/><path d="M12 9C10.34 9 9 10.34 9 12V15C9 16.66 10.34 18 12 18C13.66 18 15 16.66 15 15V12C15 10.34 13.66 9 12 9Z" fill="#ef4444"/><path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2ZM12 20C7.58 20 4 16.42 4 12C4 7.58 7.58 4 12 4C16.42 4 20 7.58 20 12C20 16.42 16.42 20 12 20Z" fill="#9ca3af"/><circle cx="16" cy="14" r="1" fill="#4b5563"/><circle cx="16" cy="17" r="1" fill="#4b5563"/></svg>`,
  // Pizza
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2ZM12 20C7.58 20 4 16.42 4 12C4 7.58 7.58 4 12 4C16.42 4 20 7.58 20 12C20 16.42 16.42 20 12 20Z" fill="#f97316"/><path d="M12 4C11.45 4 11 4.45 11 5V11L16.5 16.5C16.89 16.89 17.51 16.89 17.9 16.5L18.59 15.8C18.98 15.41 18.98 14.78 18.59 14.39L13 9V5C13 4.45 12.55 4 12 4Z" fill="#fbbf24"/><circle cx="15" cy="8" r="1" fill="#b91c1c"/><circle cx="9" cy="15" r="1" fill="#b91c1c"/><circle cx="8" cy="9" r="1" fill="#b91c1c"/></svg>`,
  // Diamond
  `<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 2L2 9.5L12 22L22 9.5L12 2Z" fill="#3b82f6"/><path d="M12 2V22L2 9.5L12 2Z" fill="#2563eb"/><path d="M12 2L22 9.5L12 14L12 2Z" fill="#60a5fa"/></svg>`,
];

const AVATAR_URLS = AVATAR_SVGS.map(svg => `data:image/svg+xml,${encodeURIComponent(svg.replace(/\s+/g, ' '))}`);

@Component({
  selector: 'app-avatar-picker',
  imports: [CommonModule],
  templateUrl: './avatar-picker.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AvatarPickerComponent {
  close = output<void>();
  avatarSelected = output<string>();

  avatars = signal<string[]>(AVATAR_URLS);

  selectAvatar(avatar: string) {
    this.avatarSelected.emit(avatar);
    this.close.emit();
  }
}
