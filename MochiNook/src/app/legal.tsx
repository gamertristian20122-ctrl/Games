import { router, useLocalSearchParams } from 'expo-router';
import React from 'react';
import { View } from 'react-native';
import { IconButton, Pill, Row, Screen, T } from '../components/ui';
import { PRIVACY_POLICY, TERMS_OF_USE } from '../data/legal';
import { useTheme } from '../theme/ThemeContext';
import { space } from '../theme/tokens';

export default function Legal() {
  const { doc } = useLocalSearchParams<{ doc?: string }>();
  const { c } = useTheme();
  const current = doc === 'terms' ? TERMS_OF_USE : PRIVACY_POLICY;

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md, justifyContent: 'space-between' }}>
        <IconButton icon="chevronLeft" label="Back" onPress={() => router.back()} />
        <Row gap={space.sm}>
          <Pill label="Privacy" selected={current === PRIVACY_POLICY} onPress={() => router.setParams({ doc: 'privacy' })} />
          <Pill label="Terms" selected={current === TERMS_OF_USE} onPress={() => router.setParams({ doc: 'terms' })} />
        </Row>
      </Row>
      <T variant="title" accessibilityRole="header" style={{ marginTop: space.lg }}>
        {current.title}
      </T>
      <T variant="small">Last updated {current.updated}</T>
      <T color={c.ink} style={{ marginTop: space.lg }}>
        {current.intro}
      </T>
      {current.sections.map((s) => (
        <View key={s.heading} style={{ marginTop: space.xl, gap: space.sm }}>
          <T variant="heading" accessibilityRole="header">
            {s.heading}
          </T>
          {s.paragraphs.map((p, i) => (
            <T key={i} color={c.inkSoft}>
              {p}
            </T>
          ))}
        </View>
      ))}
    </Screen>
  );
}
