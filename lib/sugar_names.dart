/// Added sugar hides under many names. Longer names come first so
/// "brown rice syrup" wins over "rice syrup" and "syrup".
class SugarHit {
  SugarHit(this.name, this.kind, {this.watch = false});
  final String name;
  final String kind;

  /// Not counted as sugar on labels, but behaves a lot like it.
  final bool watch;
}

const _sugars = <String, String>{
  'high fructose corn syrup': 'corn syrup',
  'glucose-fructose syrup': 'syrup',
  'fructose-glucose syrup': 'syrup',
  'evaporated cane juice': 'cane sugar',
  'fruit juice concentrate': 'concentrated juice',
  'apple juice concentrate': 'concentrated juice',
  'grape juice concentrate': 'concentrated juice',
  'pear juice concentrate': 'concentrated juice',
  'confectioner\'s sugar': 'sugar',
  'brown rice syrup': 'syrup',
  'barley malt syrup': 'syrup',
  'invert sugar syrup': 'syrup',
  'corn syrup solids': 'corn syrup',
  'caramelized sugar': 'sugar',
  'coconut sugar': 'sugar',
  'powdered sugar': 'sugar',
  'invert sugar': 'sugar',
  'icing sugar': 'sugar',
  'castor sugar': 'sugar',
  'caster sugar': 'sugar',
  'brown sugar': 'sugar',
  'cane sugar': 'sugar',
  'beet sugar': 'sugar',
  'palm sugar': 'sugar',
  'date sugar': 'sugar',
  'raw sugar': 'sugar',
  'rock sugar': 'sugar',
  'golden syrup': 'syrup',
  'glucose syrup': 'syrup',
  'maple syrup': 'syrup',
  'agave nectar': 'syrup',
  'agave syrup': 'syrup',
  'sorghum syrup': 'syrup',
  'carob syrup': 'syrup',
  'date syrup': 'syrup',
  'malt syrup': 'syrup',
  'rice syrup': 'syrup',
  'corn syrup': 'corn syrup',
  'invert syrup': 'syrup',
  'sugar syrup': 'syrup',
  'cane juice': 'cane sugar',
  'barley malt': 'malt sugar',
  'isoglucose': 'syrup',
  'muscovado': 'sugar',
  'demerara': 'sugar',
  'turbinado': 'sugar',
  'khandsari': 'sugar',
  'jaggery': 'sugar',
  'panela': 'sugar',
  'sucanat': 'sugar',
  'mishri': 'sugar',
  'molasses': 'syrup',
  'treacle': 'syrup',
  'caramel': 'cooked sugar',
  'honey': 'honey',
  'agave': 'syrup',
  'sucrose': 'sugar',
  'dextrose': 'glucose',
  'glucose': 'glucose',
  'fructose': 'fruit sugar',
  'maltose': 'malt sugar',
  'trehalose': 'sugar',
  'gur': 'jaggery',
  'sugars': 'sugar',
  'sugar': 'sugar',
};

const _watch = <String, String>{'maltodextrin': 'starch that digests like sugar', 'dextrin': 'starch that digests like sugar'};

/// Phrases on packs that mention sugar without adding it.
final _notIngredients = RegExp(
  r"(no|without|zero|free from) added sugars?|sugars?[- ]free|no sugars?|0 ?g sugars?|includes? \d+ ?g added sugars?|total sugars?|of which sugars?|sugars? \d|caramel colou?r",
  caseSensitive: false,
);

String _normalise(String raw) {
  var t = raw.replaceAll(RegExp(r'-\s*\n\s*'), '').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  t = t.replaceAll('’', '\'');
  // Labels list nutrition facts too; focus on the ingredient list when we can find it.
  final i = t.indexOf('ingredient');
  if (i >= 0) t = t.substring(i);
  return t.replaceAll(_notIngredients, ' ');
}

List<SugarHit> findSugars(String raw) {
  var text = _normalise(raw);
  final hits = <SugarHit>[];
  final seen = <String>{};
  void scan(Map<String, String> names, bool watch) {
    for (final e in names.entries) {
      final re = RegExp('(?<![a-z])${RegExp.escape(e.key)}(?![a-z])');
      if (re.hasMatch(text)) {
        final display = e.key == 'sugars' ? 'sugar' : e.key;
        if (seen.add(display)) hits.add(SugarHit(display[0].toUpperCase() + display.substring(1), e.value, watch: watch));
        // Blank it out so shorter names inside it don't match again.
        text = text.replaceAll(re, ' ');
      }
    }
  }

  scan(_watch, true);
  scan(_sugars, false);
  return hits;
}

/// Every name the scanner knows, for the "names" list on the Sugar tab.
final List<String> sugarNames = [..._sugars.keys.where((n) => n != 'sugar' && n != 'sugars'), ..._watch.keys];
