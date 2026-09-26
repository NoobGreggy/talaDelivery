import {
  AfterViewInit,
  Component,
  ElementRef,
  EventEmitter,
  Input,
  OnChanges,
  OnDestroy,
  Output,
  SimpleChanges,
  ViewChild,
} from '@angular/core';
import type { Feature, FeatureCollection, Geometry, Position } from 'geojson';
import * as maplibregl from 'maplibre-gl';
import { GeoJsonPolygon } from '../../../core/models';

@Component({
  selector: 'app-zone-boundary-map',
  standalone: true,
  templateUrl: './zone-boundary-map.html',
  styleUrl: './zone-boundary-map.css',
})
export class ZoneBoundaryMapComponent implements AfterViewInit, OnChanges, OnDestroy {
  @Input() boundary: GeoJsonPolygon | null = null;
  @Input() editable = true;
  @Output() boundaryChange = new EventEmitter<GeoJsonPolygon | null>();
  @ViewChild('mapContainer') mapContainer!: ElementRef<HTMLDivElement>;

  protected vertexCount = 0;
  private map: maplibregl.Map | null = null;
  private resizeObserver: ResizeObserver | null = null;
  private vertices: Position[] = [];
  private readonly sourceId = 'zone-boundary';

  ngAfterViewInit(): void {
    this.readBoundary();
    const map = new maplibregl.Map({
      container: this.mapContainer.nativeElement,
      style: this.baseMapStyle(),
      center: this.initialCenter(),
      zoom: this.vertices.length > 0 ? 13 : 11,
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
    map.on('load', () => {
      map.addSource(this.sourceId, { type: 'geojson', data: this.featureCollection() });
      map.addLayer({
        id: 'zone-boundary-fill',
        type: 'fill',
        source: this.sourceId,
        filter: ['==', '$type', 'Polygon'],
        paint: { 'fill-color': '#0284c7', 'fill-opacity': 0.18 },
      });
      map.addLayer({
        id: 'zone-boundary-line',
        type: 'line',
        source: this.sourceId,
        filter: ['any', ['==', '$type', 'Polygon'], ['==', '$type', 'LineString']],
        paint: { 'line-color': '#0369a1', 'line-width': 3 },
      });
      map.addLayer({
        id: 'zone-boundary-vertices',
        type: 'circle',
        source: this.sourceId,
        filter: ['==', '$type', 'Point'],
        paint: {
          'circle-radius': 5,
          'circle-color': '#ffffff',
          'circle-stroke-color': '#0369a1',
          'circle-stroke-width': 2,
        },
      });
      this.fitBoundary();
    });
    map.on('click', (event) => {
      if (!this.editable) return;
      this.vertices.push([event.lngLat.lng, event.lngLat.lat]);
      this.publishBoundary();
      this.syncSource();
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (!changes['boundary']) return;
    this.readBoundary();
    this.syncSource();
  }

  ngOnDestroy(): void {
    this.resizeObserver?.disconnect();
    this.map?.remove();
  }

  protected undoVertex(): void {
    this.vertices.pop();
    this.publishBoundary();
    this.syncSource();
  }

  protected clearBoundary(): void {
    this.vertices = [];
    this.vertexCount = 0;
    this.boundaryChange.emit(null);
    this.syncSource();
  }

  private readBoundary(): void {
    const ring = this.boundary?.coordinates?.[0] ?? [];
    this.vertices = ring.length > 1 ? ring.slice(0, -1).map((point) => [...point]) : [];
    this.vertexCount = this.vertices.length;
  }

  private publishBoundary(): void {
    this.vertexCount = this.vertices.length;
    if (this.vertices.length < 3) {
      this.boundaryChange.emit(null);
      return;
    }
    this.boundaryChange.emit({
      type: 'Polygon',
      coordinates: [[...this.vertices.map((point) => [...point]), [...this.vertices[0]]]],
    });
  }

  private featureCollection(): FeatureCollection<Geometry> {
    const features: Feature<Geometry>[] = this.vertices.map((coordinates) => ({
      type: 'Feature',
      properties: {},
      geometry: { type: 'Point', coordinates },
    }));

    if (this.vertices.length >= 2) {
      features.unshift({
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: this.vertices },
      });
    }
    if (this.vertices.length >= 3) {
      features.unshift({
        type: 'Feature',
        properties: {},
        geometry: {
          type: 'Polygon',
          coordinates: [[...this.vertices, this.vertices[0]]],
        },
      });
    }

    return { type: 'FeatureCollection', features };
  }

  private syncSource(): void {
    const source = this.map?.getSource(this.sourceId) as maplibregl.GeoJSONSource | undefined;
    source?.setData(this.featureCollection());
  }

  private initialCenter(): [number, number] {
    if (this.vertices.length === 0) return [120.9734, 15.4865];
    const longitude =
      this.vertices.reduce((sum, point) => sum + Number(point[0]), 0) / this.vertices.length;
    const latitude =
      this.vertices.reduce((sum, point) => sum + Number(point[1]), 0) / this.vertices.length;
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
    if (!map || this.vertices.length < 2) return;
    const bounds = this.vertices.reduce(
      (current, point) => current.extend([Number(point[0]), Number(point[1])]),
      new maplibregl.LngLatBounds(
        [Number(this.vertices[0][0]), Number(this.vertices[0][1])],
        [Number(this.vertices[0][0]), Number(this.vertices[0][1])],
      ),
    );
    map.fitBounds(bounds, { padding: 40, maxZoom: 15, duration: 0 });
  }
}
