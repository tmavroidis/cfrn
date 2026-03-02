// /home/tmavroidis/StudioProjects/cfrn/lib/main.dart

<<<<_audioPlayer.play(UrlSource(url)).catchError((e) {
setState(() => _isTuning = false);
_showError("Failed to play: $e");
});
====
_audioPlayer.play(UrlSource(url)).catchError((Object e) {
if (mounted) {
setState(() => _isTuning = false);
_showError("Stream Unavailable at this time");
}
});
>
>
>
>