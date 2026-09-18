import { z } from 'zod';

export const CategorySchema = z.enum(['coffee', 'food', 'scenic', 'fuel', 'toilets', 'playgrounds']);
export type Category = z.infer<typeof CategorySchema>;
export const CoordinateSchema = z.object({ latitude: z.number().min(-90).max(90), longitude: z.number().min(-180).max(180) });
export type Coordinate = z.infer<typeof CoordinateSchema>;
export const PointSchema = z.object({
  id: z.string().min(1).max(256),
  coordinate: CoordinateSchema.optional(),
}).refine(point => point.id !== 'current-location' || point.coordinate !== undefined, { message: 'Current location requires coordinates.' });
export const StopInputSchema = z.object({ place: PointSchema, visitMinutes: z.number().int().min(1).max(240) });
export const RouteInputSchema = z.object({
  origin: PointSchema, destination: PointSchema,
  stops: z.array(StopInputSchema).max(12).default([]),
  departure: z.string().datetime(),
});
export const PreferencesSchema = z.object({
  categories: z.array(CategorySchema).max(6),
  customRequest: z.string().max(600).default(''),
  maxDetourMinutes: z.number().min(1).max(120).default(20),
});
export const DiscoveryInputSchema = RouteInputSchema.extend({
  preferences: PreferencesSchema,
  reviewedIDs: z.array(z.string().max(256)).max(300).default([]),
  coveredCategories: z.array(CategorySchema).max(6).default([]),
});
export type RouteInput = z.infer<typeof RouteInputSchema>;
export type DiscoveryInput = z.infer<typeof DiscoveryInputSchema>;
export interface Attribution { name: string; uri?: string; photoURI?: string }
export interface Place {
  id: string; name: string; subtitle: string; coordinate: Coordinate;
  category: Category; rating?: number; ratingCount?: number;
  mapsURI: string; photoName?: string; photoURI?: string; photoAttributions: Attribution[];
  hours: string[]; openNow?: boolean; amenities: string[];
  allowsDogs?: boolean; goodForChildren?: boolean;
  reviews: { text: string; author: Attribution; relativeTime: string; uri?: string }[];
}
export interface SearchResult { id: string; name: string; subtitle: string }
export interface RouteLeg { durationSeconds: number; distanceMeters: number }
export interface RoutePlan {
  encodedPolyline: string; durationSeconds: number; distanceMeters: number;
  legs: RouteLeg[]; calculatedAt: string;
}
export interface Suggestion {
  place: Place; detourSeconds: number; arrivalOffsetSeconds: number;
  visitMinutes: number; reason: string; insertionIndex: number;
  unverifiedRequirements: string[];
}
export type DiscoveryEvent =
  | { type: 'progress'; message: string; count: number }
  | { type: 'candidate'; suggestion: Suggestion }
  | { type: 'warning'; message: string }
  | { type: 'complete'; suggestions: Suggestion[] }
  | { type: 'error'; message: string; code: string };

export class ServiceError extends Error {
  constructor(public code: string, message: string, public status = 502) { super(message); }
}

export interface PlacesProvider {
  autocomplete(input: string, sessionToken: string, signal: AbortSignal): Promise<SearchResult[]>;
  details(id: string, signal: AbortSignal, sessionToken?: string): Promise<Place>;
  nearby(coordinate: Coordinate, signal: AbortSignal): Promise<Place[]>;
  searchAlongRoute(query: string, polyline: string, signal: AbortSignal): Promise<Place[]>;
  photo(name: string, signal: AbortSignal): Promise<{ uri: string }>;
}
export interface RouteProvider { route(input: RouteInput, signal: AbortSignal): Promise<RoutePlan> }

export const IntentSchema = z.object({
  queries: z.array(z.string().max(160)).max(3),
  categories: z.array(CategorySchema).max(6),
  requirements: z.array(z.enum(['dogs', 'children', 'charging', 'toilets'])).max(4),
  timing: z.enum(['early', 'middle', 'late', 'any']),
  visitMinutes: z.number().int().min(1).max(240).nullable(),
});
export type Intent = z.infer<typeof IntentSchema>;
export interface IntentProvider { interpret(prompt: string, categories: Category[], signal: AbortSignal): Promise<Intent> }
