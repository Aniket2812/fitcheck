{{flutter_js}}
{{flutter_build_config}}

// Keep the renderer self-contained. Depending on the public gstatic CDN made
// the app open to a blank screen on restricted or unstable networks even
// though Flutter already ships CanvasKit in the production bundle.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
