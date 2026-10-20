// SimCs Buff-Namen aus seinem Quellcode (tools/lib/simc-buffs.js).
const { simcBuffMap } = require('../lib/simc-buffs');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

// Die Schreibweisen, wie sie in SimC stehen (gekuerzt).
const quelle = `
  buffs.hammer_of_light_free =
      make_buff( this, "hammer_of_light_free", find_spell( 433732 ) )->set_default_value_from_effect(1);
  spell.lesser_ghoul_buff               = conditional_spell_lookup( spec.festering_strike->ok(), 1254252 );
  buffs.lesser_ghoul_ready =
      make_fallback( spec.festering_strike->ok(), this, "lesser_ghoul_ready", spell.lesser_ghoul_buff );
  hero_spec.voidfall_spending_buff       = talent_spell_lookup( talent.annihilator.voidfall, 1256302 );
  voidfall_spending_buff_t( demon_hunter_t* p ) : base_t( *p, "voidfall_spending", p->hero_spec.voidfall_spending_buff )
  buffs.nightfall = make_buff( this, "nightfall", talents.nightfall_buff );
  talents.nightfall_buff = find_spell( 264571 );
  buffs.pet_movement = make_buff( this, "pet_movement" )
  std::array<unsigned int, 3> supercharger_ids = { 470398, 470406, 470409 };
  for ( size_t i = 0; i < supercharger_ids.size(); i++ )
    buffs.supercharger.emplace_back( make_buff( this, fmt::format( "supercharge_{}", i + 1 ), talent.rogue.supercharger->ok() ?
                                                find_spell( supercharger_ids[ i ] ) : spell_data_t::not_found() ) );
`;
const map = simcBuffMap(quelle);
check('direkt mit find_spell', map.get('hammer_of_light_free'), 433732);
check('ueber eine Zuweisung (Todesritter)', map.get('lesser_ghoul_ready'), 1254252);
check('ueber den Heldenbaum (Daemonenjaeger)', map.get('voidfall_spending'), 1256302);
check('Zuweisung steht weiter unten (Hexenmeister)', map.get('nightfall'), 264571);
check('ohne Zauber kein Eintrag', map.has('pet_movement'), false);
check('in einer Schleife angelegt (Schurke)', [map.get('supercharge_1'), map.get('supercharge_3')], [470398, 470409]);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
