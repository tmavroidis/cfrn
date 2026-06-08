// /home/tmavroidis/StudioProjects/cfrn/lib/main.dart

<<<<void _audioPlayer.void play(UrlSource(url)).catchError((e) {
setState(() => _isTuning = false);
_showError("Failed to play: $e");
});
====
void _audioPlayer.void play(UrlSource(url)).catchError((Object e) {
if (mounted) {
setState(() => _isTuning = false);
_showError("Stream Unavailable at this time");
}
});
>
>
>
>