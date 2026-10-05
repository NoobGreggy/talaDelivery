import { Injectable } from '@nestjs/common';
import type { GeoJsonBoundary } from '../entities/delivery-zone.entity';

type Point = [number, number];
type Ring = Point[];
type Polygon = Ring[];
type PolygonCollection = Polygon[];

/**
 * Point-in-polygon + polygon-overlap checks for GeoJSON coverage boundaries.
 * Ported 1:1 from Laravel ZoneBoundaryService (ray casting, boundary inclusive).
 */
@Injectable()
export class ZoneBoundaryService {
  covers(boundary: GeoJsonBoundary, latitude: number, longitude: number): boolean {
    for (const polygon of this.polygons(boundary)) {
      const outerRing = polygon[0] ?? [];
      if (!this.ringContains(outerRing, latitude, longitude, true)) {
        continue;
      }

      const insideHole = polygon
        .slice(1)
        .some((hole: Ring): boolean => this.ringContains(hole, latitude, longitude, true));

      if (!insideHole) {
        return true;
      }
    }

    return false;
  }

  overlaps(first: GeoJsonBoundary, second: GeoJsonBoundary): boolean {
    if (first === second) {
      return true;
    }

    for (const firstPolygon of this.polygons(first)) {
      for (const secondPolygon of this.polygons(second)) {
        if (this.polygonsOverlap(firstPolygon, secondPolygon)) {
          return true;
        }
      }
    }

    return false;
  }

  private polygonsOverlap(first: Polygon, second: Polygon): boolean {
    const firstOuterRing = first[0] ?? [];
    const secondOuterRing = second[0] ?? [];

    for (const [longitude, latitude] of firstOuterRing.slice(0, -1)) {
      if (this.ringContains(secondOuterRing, Number(latitude), Number(longitude), false)) {
        return true;
      }
    }

    for (const [longitude, latitude] of secondOuterRing.slice(0, -1)) {
      if (this.ringContains(firstOuterRing, Number(latitude), Number(longitude), false)) {
        return true;
      }
    }

    for (let firstIndex = 1; firstIndex < firstOuterRing.length; firstIndex++) {
      for (let secondIndex = 1; secondIndex < secondOuterRing.length; secondIndex++) {
        if (
          this.segmentsProperlyIntersect(
            firstOuterRing[firstIndex - 1],
            firstOuterRing[firstIndex],
            secondOuterRing[secondIndex - 1],
            secondOuterRing[secondIndex],
          )
        ) {
          return true;
        }
      }
    }

    return false;
  }

  private ringContains(
    ring: Ring,
    latitude: number,
    longitude: number,
    includeBoundary: boolean,
  ): boolean {
    if (ring.length < 4) {
      return false;
    }

    let inside = false;
    const lastIndex = ring.length - 1;

    for (let index = 0, previous = lastIndex; index <= lastIndex; previous = index++) {
      const [currentLongitude, currentLatitude] = ring[index];
      const [previousLongitude, previousLatitude] = ring[previous];

      if (
        this.pointIsOnSegment(
          longitude,
          latitude,
          Number(previousLongitude),
          Number(previousLatitude),
          Number(currentLongitude),
          Number(currentLatitude),
        )
      ) {
        return includeBoundary;
      }

      const crossesLatitude =
        Number(currentLatitude) > latitude !== Number(previousLatitude) > latitude;
      if (!crossesLatitude) {
        continue;
      }

      const intersectionLongitude =
        ((Number(previousLongitude) - Number(currentLongitude)) *
          (latitude - Number(currentLatitude))) /
          (Number(previousLatitude) - Number(currentLatitude)) +
        Number(currentLongitude);

      if (longitude < intersectionLongitude) {
        inside = !inside;
      }
    }

    return inside;
  }

  private pointIsOnSegment(
    pointX: number,
    pointY: number,
    startX: number,
    startY: number,
    endX: number,
    endY: number,
  ): boolean {
    const crossProduct =
      (pointY - startY) * (endX - startX) - (pointX - startX) * (endY - startY);
    if (Math.abs(crossProduct) > 0.0000001) {
      return false;
    }

    return (
      pointX >= Math.min(startX, endX) - 0.0000001 &&
      pointX <= Math.max(startX, endX) + 0.0000001 &&
      pointY >= Math.min(startY, endY) - 0.0000001 &&
      pointY <= Math.max(startY, endY) + 0.0000001
    );
  }

  private segmentsProperlyIntersect(
    firstStart: Point,
    firstEnd: Point,
    secondStart: Point,
    secondEnd: Point,
  ): boolean {
    const orientationOne = this.orientation(firstStart, firstEnd, secondStart);
    const orientationTwo = this.orientation(firstStart, firstEnd, secondEnd);
    const orientationThree = this.orientation(secondStart, secondEnd, firstStart);
    const orientationFour = this.orientation(secondStart, secondEnd, firstEnd);

    return (
      orientationOne !== 0 &&
      orientationTwo !== 0 &&
      orientationThree !== 0 &&
      orientationFour !== 0 &&
      orientationOne !== orientationTwo &&
      orientationThree !== orientationFour
    );
  }

  private orientation(start: Point, end: Point, point: Point): number {
    const value =
      (Number(end[1]) - Number(start[1])) * (Number(point[0]) - Number(end[0])) -
      (Number(end[0]) - Number(start[0])) * (Number(point[1]) - Number(end[1]));

    return value > 0 ? 1 : value < 0 ? -1 : 0;
  }

  private polygons(boundary: GeoJsonBoundary): PolygonCollection {
    const coordinates = boundary.coordinates as unknown as PolygonCollection;
    return boundary.type === 'MultiPolygon'
      ? coordinates
      : [coordinates as unknown as Polygon];
  }
}