import { router } from 'expo-router';
import React from 'react';
import { Alert, View } from 'react-native';
import { Pet } from '../components/Pet';
import { PlusPaywall } from '../components/PlusPaywall';
import { IconButton, Row, Screen, T } from '../components/ui';
import { useTheme } from '../theme/ThemeContext';
import { space } from '../theme/tokens';

export default function Plus() {
  const { c, motionLevel } = useTheme();
  const unlocked = () => {
    Alert.alert('Plus is on!', 'Thank you so much. Your mochi has a whole new wardrobe to try.', [{ text: 'Yay', onPress: () => router.back() }]);
  };
  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ justifyContent: 'flex-end', paddingTop: space.md }}>
        <IconButton icon="close" label="Close" onPress={() => router.back()} />
      </Row>
      <View style={{ alignItems: 'center' }}>
        <Pet color="lavender" hat="wizard" scarf="stripes" mood="happy" size={160} level={motionLevel} tappable />
        <T variant="hero" style={{ textAlign: 'center', marginTop: space.md }}>
          MochiNook Plus
        </T>
        <T color={c.inkSoft} style={{ textAlign: 'center', marginTop: space.xs, marginBottom: space.lg }}>
          Everything in Free stays free forever. Plus adds a few extra-cozy things.
        </T>
      </View>
      <PlusPaywall onUnlocked={unlocked} />
    </Screen>
  );
}
