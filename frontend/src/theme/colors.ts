// Todoist-inspired design tokens
export const C = {
  // Brand
  primary: '#e44232',
  primaryHover: '#cf3520',
  primaryLight: '#fff6f0',
  primaryMid: '#ffefe5',

  // Backgrounds
  background: '#fefdfc',
  surface: '#ffffff',
  surfaceAlt: '#f9f7f6',
  surfaceHover: '#f2efed',

  // Borders
  border: 'rgba(37, 34, 30, 0.18)',
  borderLight: 'rgba(37, 34, 30, 0.12)',

  // Text
  textPrimary: '#25221e',
  textSecondary: 'rgba(37, 34, 30, 0.66)',
  textTertiary: 'rgba(37, 34, 30, 0.49)',
  textPlaceholder: '#97938c',
  textOnPrimary: '#ffffff',

  // Semantic
  destructive: '#e34432',
  destructiveLight: '#fff6f0',

  // Radius
  radiusSm: 6,
  radiusBase: 8,
  radiusLg: 10,
  radiusXl: 13,
  radius2xl: 15,
  radiusFull: 9999,

  // Shadows (iOS)
  shadowSm: {
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
    elevation: 2,
  },
  shadowMd: {
    shadowColor: '#000',
    shadowOpacity: 0.12,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 3 },
    elevation: 4,
  },
} as const;

export const paperTheme = {
  colors: {
    primary: C.primary,
    onPrimary: C.textOnPrimary,
    primaryContainer: C.primaryLight,
    onPrimaryContainer: C.primaryHover,
    secondary: C.textSecondary,
    background: C.background,
    surface: C.surface,
    onSurface: C.textPrimary,
    onSurfaceVariant: C.textSecondary,
    outline: C.border,
    error: C.destructive,
  },
};
