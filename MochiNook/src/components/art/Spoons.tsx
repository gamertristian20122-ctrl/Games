import React from 'react';
import { View } from 'react-native';
import { Glyph } from './Glyph';

/** 1–3 little spoons, overlapping like a hand of cards. */
export function Spoons({ count, size = 22 }: { count: number; size?: number }) {
  return (
    <View style={{ flexDirection: 'row' }} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      {Array.from({ length: count }, (_, i) => (
        <View key={i} style={{ marginLeft: i === 0 ? 0 : -size * 0.45 }}>
          <Glyph name="spoon" size={size} />
        </View>
      ))}
    </View>
  );
}
