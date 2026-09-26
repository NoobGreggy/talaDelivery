import {
  AfterViewInit,
  Component,
  ElementRef,
  EventEmitter,
  Input,
  isDevMode,
  OnChanges,
  OnDestroy,
  Output,
  SimpleChanges,
  ViewChild,
} from '@angular/core';
import type { Feature, FeatureCollection, Geometry, Position } from 'geojson';
import * as maplibregl from 'maplibre-gl';
import { GeoJsonBoundary } from '../../../core/models';

const COVERAGE_SOURCE_ID = 'zone-coverage';
const DRAWING_SOURCE_ID = 'zone-drawing';
const EMPTY_COLLECTION: FeatureCollection = { type: 'FeatureCollection', features: [] };

@Component({
  selector: 'app-zone-boundary-map',
  standalone: true,
  templateUrl: './zone-boundary-map.html',
  styleUrl: './zone-boundary-map.css',
})
export class ZoneBoundaryMapComponent implements AfterViewInit, OnChanges, OnDestroy {
  @Input() boundary: GeoJsonBoundary | null = null;
  @Input() editable = true;
  @Output() boundaryChange = new EventEmitter<GeoJsonBoundary | null>();
  @ViewChild('mapContainer') mapContainer!: ElementRef<HTMLDivElement>;

  protected vertexCount = 0;
  protected hasImportedBoundary = false;
  protected drawingMode = false;
  private map: maplibregl.Map | null = null;
  private resizeObserver: ResizeObserver | null = null;
  private vertices: Position[] = [];
  private lastPublishedBoundary: GeoJsonBoundary | null | undefined;

  ngAfterViewInit(): void {
    this.readBoundary();
    const map = new maplibregl.Map({
      container: this.mapContainer.nativeElement,
      style: this.baseMapStyle(),
      center: this.initialCenter(),
      zoom: this.focusPoints().length > 0 ? 13 : 11,
      minZoom: 5,
      maxZoom: 19,
      fadeDuration: 0,
      renderWorldCopies: false,
      attributionControl: { compact: true },
    });
    this.map = map;
    this.resizeObserver = new ResizeObserver(() => map.resize());
    this.resizeObserver.observe(this.mapContainer.nativeElement);
    requestAnimationFrame(() => map.resize());
    map.addControl(new maplibregl.NavigationControl(), 'top-right');
    if (isDevMode()) {
      map.on('error', (event) => {
        console.error('Zone map rendering error', event.error);
      });
    }
    map.on('load', () => {
      map.addSource(COVERAGE_SOURCE_ID, { type: 'geojson', data: EMPTY_COLLECTION });
      map.addSource(DRAWING_SOURCE_ID, { type: 'geojson', data: EMPTY_COLLECTION });
      this.addCoverageLayers(map);
      this.addDrawingLayers(map);
      this.syncMapSources();
      this.fitBoundary();
    });
    map.on('click', (event) => {
      if (!this.editable || !this.drawingMode) return;
      this.vertices.push([event.lngLat.lng, event.lngLat.lat]);
      this.publishBoundary();
      this.syncMapSources();
    });
    map.on('dblclick', (event) => {
      if (this.drawingMode) event.preventDefault();
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (!changes['boundary']) return;
    if (
      this.lastPublishedBoundary !== undefined &&
      this.sameBoundary(this.boundary, this.lastPublishedBoundary)
    ) {
      return;
    }
    this.lastPublishedBoundary = undefined;
    this.readBoundary();
    this.syncMapSources();
    requestAnimationFrame(() => this.fitBoundary());
  }

  ngOnDestroy(): void {
    this.resizeObserver?.disconnect();
    this.map?.remove();
  }

  protected undoVertex(): void {
    this.vertices.pop();
    this.publishBoundary();
    this.syncMapSources();
  }

  protected clearBoundary(): void {
    this.vertices = [];
    this.hasImportedBoundary = false;
    this.setDrawingMode(false);
    this.vertexCount = 0;
    this.emitBoundary(null);
    this.syncMapSources();
  }

  protected startDrawing(): void {
    this.vertices = [];
    this.hasImportedBoundary = false;
    this.vertexCount = 0;
    this.emitBoundary(null);
    this.setDrawingMode(true);
    this.syncMapSources();
  }

  protected finishDrawing(): void {
    if (this.vertices.length < 3) return;
    this.setDrawingMode(false);
    this.syncMapSources();
  }

  private addCoverageLayers(map: maplibregl.Map): void {
    map.addLayer({
      id: 'zone-coverage-fill',
      type: 'fill',
      source: COVERAGE_SOURCE_ID,
      paint: {
        'fill-color': '#2563eb',
        'fill-opacity': 0.55,
        'fill-outline-color': '#1e3a8a',
      },
    });
    map.addLayer({
      id: 'zone-coverage-casing',
      type: 'line',
      source: COVERAGE_SOURCE_ID,
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: { 'line-color': '#ffffff', 'line-width': 8, 'line-opacity': 0.95 },
    });
    map.addLayer({
      id: 'zone-coverage-outline',
      type: 'line',
      source: COVERAGE_SOURCE_ID,
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: { 'line-color': '#1d4ed8', 'line-width': 4 },
    });
  }

  private addDrawingLayers(map: maplibregl.Map): void {
    map.addLayer({
      id: 'zone-drawing-line',
      type: 'line',
      source: DRAWING_SOURCE_ID,
      layout: { 'line-join': 'round', 'line-cap': 'round' },
      paint: { 'line-color': '#1d4ed8', 'line-width': 3, 'line-opacity': 0.9 },
    });
    map.addLayer({
      id: 'zone-drawing-vertices',
      type: 'circle',
      source: DRAWING_SOURCE_ID,
      paint: {
        'circle-radius': 5,
        'circle-color': '#2563eb',
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 3,
      },
    });
  }

  private readBoundary(): void {
    this.vertices = [];
    this.hasImportedBoundary = this.boundary !== null;
    this.setDrawingMode(false);
    this.vertexCount = this.boundary === null ? 0 : this.boundaryPoints().length;
  }

  private publishBoundary(): void {
    this.vertexCount = this.vertices.length;
    if (this.vertices.length < 3) {
      this.emitBoundary(null);
      return;
    }
    this.emitBoundary({
      type: 'Polygon',
      coordinates: [this.closedRing()],
    });
  }

  private emitBoundary(boundary: GeoJsonBoundary | null): void {
    this.lastPublishedBoundary = boundary;
    this.boundaryChange.emit(boundary);
  }

  private closedRing(): Position[] {
    return [...this.vertices.map((point) => [...point]), [...this.vertices[0]]];
  }

  private coverageGeometry(): GeoJsonBoundary | null {
    if (this.vertices.length >= 3) {
      return { type: 'Polygon', coordinates: [this.closedRing()] };
    }
    if (this.hasImportedBoundary && this.boundary !== null) {
      return this.boundary;
    }
    return null;
  }

  private coverageData(): FeatureCollection {
    const geometry = this.coverageGeometry();
    if (geometry === null) return EMPTY_COLLECTION;
    return {
      type: 'FeatureCollection',
      features: [{ type: 'Feature', properties: { coverage: true }, geometry }],
    };
  }

  private drawingData(): FeatureCollection<Geometry> {
    if (!this.drawingMode) return EMPTY_COLLECTION;
    const features: Feature<Geometry>[] = [];
    if (this.vertices.length >= 2) {
      features.push({
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: this.vertices.map((point) => [...point]) },
      });
    }
    for (const point of this.vertices) {
      features.push({
        type: 'Feature',
        properties: {},
        geometry: { type: 'Point', coordinates: [...point] },
      });
    }
    return { type: 'FeatureCollection', features };
  }

  private syncMapSources(): void {
    const map = this.map;
    if (map === null) return;
    const coverage = map.getSource(COVERAGE_SOURCE_ID) as maplibregl.GeoJSONSource | undefined;
    const drawing = map.getSource(DRAWING_SOURCE_ID) as maplibregl.GeoJSONSource | undefined;
    coverage?.setData(this.coverageData());
    drawing?.setData(this.drawingData());
    map.triggerRepaint();
  }

  private setDrawingMode(enabled: boolean): void {
    this.drawingMode = enabled;
    const map = this.map;
    if (map === null) return;

    map.getCanvas().style.cursor = enabled ? 'crosshair' : '';
    if (enabled) {
      map.doubleClickZoom.disable();
    } else {
      map.doubleClickZoom.enable();
    }
  }

  private sameBoundary(left: GeoJsonBoundary | null, right: GeoJsonBoundary | null): boolean {
    if (left === right) return true;
    if (left === null || right === null) return false;
    return this.sameCoordinates(left.coordinates, right.coordinates);
  }

  private sameCoordinates(left: unknown, right: unknown): boolean {
    if (left === right) return true;
    if (typeof left === 'number' || typeof right === 'number') {
      return left === right;
    }
    if (!Array.isArray(left) || !Array.isArray(right)) return false;
    if (left.length !== right.length) return false;
    return left.every((value, index) => this.sameCoordinates(value, right[index]));
  }

  private focusPoints(): Position[] {
    return this.vertices.length > 0 ? this.vertices : this.boundaryPoints();
  }

  private initialCenter(): [number, number] {
    const points = this.focusPoints();
    if (points.length === 0) return [120.9734, 15.4865];
    const longitude = points.reduce((sum, point) => sum + Number(point[0]), 0) / points.length;
    const latitude = points.reduce((sum, point) => sum + Number(point[1]), 0) / points.length;
    return [longitude, latitude];
  }

  private baseMapStyle(): maplibregl.StyleSpecification {
    return {
      version: 8,
      sources: {
        openStreetMap: {
          type: 'raster',
          tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
          tileSize: 256,
          maxzoom: 19,
          attribution: '© OpenStreetMap contributors',
        },
      },
      layers: [
        {
          id: 'open-street-map',
          type: 'raster',
          source: 'openStreetMap',
          minzoom: 0,
          maxzoom: 19,
        },
      ],
    };
  }

  private fitBoundary(): void {
    const map = this.map;
    const points = this.focusPoints();
    if (!map || points.length < 2) return;
    const bounds = points.reduce(
      (current, point) => current.extend([Number(point[0]), Number(point[1])]),
      new maplibregl.LngLatBounds(
        [Number(points[0][0]), Number(points[0][1])],
        [Number(points[0][0]), Number(points[0][1])],
      ),
    );
    map.fitBounds(bounds, { padding: 40, maxZoom: 15, duration: 0 });
  }

  private boundaryPoints(): Position[] {
    const boundary = this.boundary;
    if (boundary === null) return [];
    if (boundary.type === 'Polygon') {
      return this.openRing(boundary.coordinates[0] ?? []);
    }
    return boundary.coordinates.flatMap((polygon) => this.openRing(polygon[0] ?? []));
  }

  private openRing(ring: Position[]): Position[] {
    if (ring.length === 0) return [];
    const first = ring[0];
    const last = ring[ring.length - 1];
    const closed =
      ring.length > 1 &&
      Number(first[0]) === Number(last[0]) &&
      Number(first[1]) === Number(last[1]);
    return (closed ? ring.slice(0, -1) : ring).map((point) => [...point]);
  }
}
