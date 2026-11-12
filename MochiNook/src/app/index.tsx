import { Redirect } from 'expo-router';
import React from 'react';
import { useApp } from '../state/AppContext';

export default function Index() {
  const { settings } = useApp();
  return <Redirect href={settings.onboarded ? '/home' : '/welcome'} />;
}
