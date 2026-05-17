export const locationState = $state<{
  lat: number;
  lng: number;
  error: string | null;
  tracking: boolean;
}>({
  lat: 32.8801,
  lng: -117.234,
  error: null,
  tracking: false
});

let watchId: number | null = null;

export function startTracking() {
  if (!navigator.geolocation) {
    locationState.error = 'Geolocation not available';
    return;
  }

  locationState.tracking = true;
  locationState.error = null;

  watchId = navigator.geolocation.watchPosition(
    (pos) => {
      const { latitude, longitude } = pos.coords;
      locationState.lat = latitude;
      locationState.lng = longitude;
    },
    (err) => {
      locationState.error = err.message;
    },
    { enableHighAccuracy: true, maximumAge: 60000, timeout: 10000 }
  );
}

export function stopTracking() {
  if (watchId !== null) {
    navigator.geolocation.clearWatch(watchId);
    watchId = null;
  }
  locationState.tracking = false;
}
