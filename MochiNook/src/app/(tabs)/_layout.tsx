import { Tabs } from 'expo-router/tabs';
import React from 'react';
import { Icon, type IconName } from '../../components/Icon';
import { useTheme } from '../../theme/ThemeContext';
import { fonts } from '../../theme/tokens';

const TABS: { name: string; title: string; icon: IconName }[] = [
  { name: 'home', title: 'Today', icon: 'home' },
  { name: 'quests', title: 'Quests', icon: 'list' },
  { name: 'week', title: 'Week', icon: 'sparkle' },
  { name: 'nook', title: 'Nook', icon: 'shirt' },
  { name: 'settings', title: 'Settings', icon: 'gear' },
];

export default function TabsLayout() {
  const { c } = useTheme();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: c.accentInk,
        tabBarInactiveTintColor: c.inkSoft,
        tabBarStyle: { backgroundColor: c.surface, borderTopColor: c.border, minHeight: 64, paddingTop: 6 },
        tabBarLabelStyle: { fontFamily: fonts.bodyBold, fontSize: 12 },
        sceneStyle: { backgroundColor: c.bg },
        animation: 'none',
      }}
    >
      {TABS.map((t) => (
        <Tabs.Screen
          key={t.name}
          name={t.name}
          options={{
            title: t.title,
            tabBarIcon: ({ color, focused }) => <Icon name={t.icon} color={String(color)} size={24} strokeWidth={focused ? 2.4 : 2} />,
          }}
        />
      ))}
    </Tabs>
  );
}
