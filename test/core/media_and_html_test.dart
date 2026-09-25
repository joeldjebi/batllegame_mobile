import 'package:battlegame/core/media/media_cache.dart';
import 'package:battlegame/core/widgets/rich_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the file extension in media cache keys (iOS needs it)', () {
    expect(mediaFileKey('preselection-24', 'https://s3.wasabisys.com/b/preselections/9/abc.mp4?X-Amz-Signature=1'), 'preselection-24.mp4');
    expect(mediaFileKey('media-3', 'http://127.0.0.1/storage/x/y.MOV'), 'media-3.mov');
    expect(mediaFileKey('media-4', 'http://127.0.0.1/stream'), 'media-4');
  });

  test('parses the editor HTML into blocks and decodes entities', () {
    final blocks = parseHtmlBlocks('<h2>Règles</h2><p><strong>Durée</strong> : 3 min, l&#039;artiste &amp; son DJ</p><ul><li>Un</li><li>Deux</li></ul>');

    expect(blocks.map((b) => b.kind), [HtmlBlockKind.heading, HtmlBlockKind.paragraph, HtmlBlockKind.bullet, HtmlBlockKind.bullet]);
    expect(blocks[1].inline.first.bold, isTrue);
    expect(blocks[1].inline.map((r) => r.text).join(), "Durée : 3 min, l'artiste & son DJ");
  });
}
