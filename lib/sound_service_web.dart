// lib/sound_service_web.dart — Web Audio API implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void playTone(double freq, double dur, double vol, String shape) {
  try {
    js.context.callMethod('eval', [
      '''
      (function(){
        try {
          var ctx = new (window.AudioContext || window.webkitAudioContext)();
          var o = ctx.createOscillator();
          var g = ctx.createGain();
          o.type = '$shape';
          o.connect(g);
          g.connect(ctx.destination);
          o.frequency.value = $freq;
          g.gain.setValueAtTime($vol, ctx.currentTime);
          g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + $dur);
          o.start(ctx.currentTime);
          o.stop(ctx.currentTime + $dur + 0.05);
        } catch(e) {}
      })();
      '''
    ]);
  } catch (_) {}
}
