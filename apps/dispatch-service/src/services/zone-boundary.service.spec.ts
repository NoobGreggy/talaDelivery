import type { GeoJsonBoundary } from '../entities/delivery-zone.entity';
import { ZoneBoundaryService } from './zone-boundary.service';

const service = new ZoneBoundaryService();

function polygon(rings: number[][][]): GeoJsonBoundary {
  return { type: 'Polygon', coordinates: rings };
}

function square(lngMin: number, latMin: number, lngMax: number, latMax: number): number[][][] {
  return [
    [
      [lngMin, latMin],
      [lngMax, latMin],
      [lngMax, latMax],
      [lngMin, latMax],
      [lngMin, latMin],
    ],
  ];
}

const MAKATI = square(121.0, 14.5, 121.1, 14.6);

describe('ZoneBoundaryService.covers', () => {
  it('covers a point inside the polygon', () => {
    expect(service.covers(polygon(MAKATI), 14.55, 121.05)).toBe(true);
  });

  it('covers a point exactly on the boundary (boundary inclusive)', () => {
    expect(service.covers(polygon(MAKATI), 14.5, 121.0)).toBe(true);
    expect(service.covers(polygon(MAKATI), 14.5, 121.05)).toBe(true);
    expect(service.covers(polygon(MAKATI), 14.6, 121.1)).toBe(true);
  });

  it('does not cover a point outside the polygon', () => {
    expect(service.covers(polygon(MAKATI), 14.7, 121.2)).toBe(false);
  });

  it('excludes points inside a hole', () => {
    const withHole = polygon([
      ...MAKATI,
      [
        [121.02, 14.52],
        [121.06, 14.52],
        [121.06, 14.56],
        [121.02, 14.56],
        [121.02, 14.52],
      ],
    ]);
    expect(service.covers(withHole, 14.54, 121.04)).toBe(false);
    expect(service.covers(withHole, 14.55, 121.08)).toBe(true);
  });

  it('covers a point in any polygon of a MultiPolygon', () => {
    const multi: GeoJsonBoundary = {
      type: 'MultiPolygon',
      coordinates: [
        MAKATI,
        [[ [122.0, 15.0], [122.1, 15.0], [122.1, 15.1], [122.0, 15.1], [122.0, 15.0] ]],
      ],
    };
    expect(service.covers(multi, 14.55, 121.05)).toBe(true);
    expect(service.covers(multi, 15.05, 122.05)).toBe(true);
    expect(service.covers(multi, 14.7, 121.2)).toBe(false);
  });

  it('rejects degenerate rings', () => {
    expect(service.covers(polygon([[ [121.0, 14.5], [121.1, 14.5] ]]), 14.55, 121.05)).toBe(false);
  });
});

describe('ZoneBoundaryService.overlaps', () => {
  it('reports overlap for the same object reference', () => {
    const boundary = polygon(MAKATI);
    expect(service.overlaps(boundary, boundary)).toBe(true);
  });

  it('reports overlap when polygons share area', () => {
    const second = square(121.05, 14.55, 121.15, 14.65);
    expect(service.overlaps(polygon(MAKATI), polygon(second))).toBe(true);
  });

  it('reports overlap when one polygon is nested inside the other', () => {
    const nested = square(121.02, 14.52, 121.06, 14.56);
    expect(service.overlaps(polygon(MAKATI), polygon(nested))).toBe(true);
    expect(service.overlaps(polygon(nested), polygon(MAKATI))).toBe(true);
  });

  it('reports no overlap for disjoint polygons', () => {
    const elsewhere = square(122.0, 15.0, 122.1, 15.1);
    expect(service.overlaps(polygon(MAKATI), polygon(elsewhere))).toBe(false);
  });

  it('treats polygons touching only along an edge as non-overlapping', () => {
    const adjacent = square(121.1, 14.5, 121.2, 14.6);
    expect(service.overlaps(polygon(MAKATI), polygon(adjacent))).toBe(false);
  });

  it('detects overlap across a MultiPolygon pair', () => {
    const multi: GeoJsonBoundary = {
      type: 'MultiPolygon',
      coordinates: [
        MAKATI,
        [[ [122.0, 15.0], [122.1, 15.0], [122.1, 15.1], [122.0, 15.1], [122.0, 15.0] ]],
      ],
    };
    const overlappingMulti = square(122.05, 15.05, 122.2, 15.2);
    expect(service.overlaps(multi, polygon(overlappingMulti))).toBe(true);
  });
});