import {
  AfterViewInit,
  Component,
  ElementRef,
  Input,
  OnChanges,
  OnDestroy,
  SimpleChanges,
  ViewChild,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import * as mapboxgl from 'mapbox-gl';
import { LngLatBounds, Map, Marker } from 'mapbox-gl';
import { Delivery } from '../../../core/models';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-delivery-tracking-map',
  standalone: true,
  imports: [DatePipe],
  templateUrl: './delivery-tracking-map.html',
  styleUrl: './delivery-tracking-map.css',
})
export class DeliveryTrackingMapComponent implements AfterViewInit, OnChanges, OnDestroy {
  @Input({ required: true }) delivery!: Delivery;
  @ViewChild('mapContainer') mapContainer!: ElementRef<HTMLDivElement>;

  private map: Map | null = null;
  private pickupMarker: Marker | null = null;
  private destinationMarker: Marker | null = null;
  private riderMarker: Marker | null = null;
  protected readonly mapboxConfigured = environment.mapboxAccessToken.trim().length > 0;

  ngAfterViewInit(): void {
    if (!this.mapboxConfigured) return;
    const center = this.initialCenter();
    const map = new mapboxgl.Map({
      accessToken: environment.mapboxAccessToken,
      container: this.mapContainer.nativeElement,
      style: 'mapbox://styles/mapbox/streets-v12',
      center,
      zoom: 13,
      attributionControl: true,
    });
    this.map = map;
    map.addControl(new mapboxgl.NavigationControl(), 'top-right');
    map.on('load', () => this.syncMarkers(true));
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['delivery'] && this.map?.loaded()) {
      this.syncMarkers(false);
    }
  }

  ngOnDestroy(): void {
    this.pickupMarker?.remove();
    this.destinationMarker?.remove();
    this.riderMarker?.remove();
    this.map?.remove();
  }

  private initialCenter(): [number, number] {
    const rider = this.delivery.rider_location;
    if (rider) return [Number(rider.longitude), Number(rider.latitude)];
    if (this.delivery.delivery_latitude != null && this.delivery.delivery_longitude != null) {
      return [Number(this.delivery.delivery_longitude), Number(this.delivery.delivery_latitude)];
    }
    if (this.delivery.pickup_latitude != null && this.delivery.pickup_longitude != null) {
      return [Number(this.delivery.pickup_longitude), Number(this.delivery.pickup_latitude)];
    }
    return [120.9734, 15.4865];
  }

  private syncMarkers(fitBounds: boolean): void {
    const map = this.map;
    if (!map) return;
    const points: [number, number][] = [];

    if (this.delivery.pickup_latitude != null && this.delivery.pickup_longitude != null) {
      const pickup: [number, number] = [
        Number(this.delivery.pickup_longitude),
        Number(this.delivery.pickup_latitude),
      ];
      points.push(pickup);
      const pickupMarker =
        this.pickupMarker ??
        new mapboxgl.Marker({ color: '#2563eb' })
          .setLngLat(pickup)
          .setPopup(new mapboxgl.Popup().setText('Pickup'))
          .addTo(map);
      this.pickupMarker = pickupMarker;
      pickupMarker.setLngLat(pickup);
    }

    if (this.delivery.delivery_latitude != null && this.delivery.delivery_longitude != null) {
      const destination: [number, number] = [
        Number(this.delivery.delivery_longitude),
        Number(this.delivery.delivery_latitude),
      ];
      points.push(destination);
      const destinationMarker =
        this.destinationMarker ??
        new mapboxgl.Marker({ color: '#16a34a' })
          .setLngLat(destination)
          .setPopup(new mapboxgl.Popup().setText('Customer'))
          .addTo(map);
      this.destinationMarker = destinationMarker;
      destinationMarker.setLngLat(destination);
    }

    const rider = this.delivery.rider_location;
    if (rider) {
      const riderPoint: [number, number] = [Number(rider.longitude), Number(rider.latitude)];
      points.push(riderPoint);
      const riderMarker =
        this.riderMarker ??
        new mapboxgl.Marker({ color: '#f97316' })
          .setLngLat(riderPoint)
          .setPopup(new mapboxgl.Popup().setText('Rider'))
          .addTo(map);
      this.riderMarker = riderMarker;
      riderMarker.setLngLat(riderPoint);
    }

    if (fitBounds && points.length > 1) {
      const bounds = points.reduce(
        (current, point) => current.extend(point),
        new LngLatBounds(points[0], points[0]),
      );
      map.fitBounds(bounds, { padding: 60, maxZoom: 16, duration: 0 });
    }
  }
}
