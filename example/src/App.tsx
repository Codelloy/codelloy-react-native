import { useEffect, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import * as Codelloy from '@codelloy/react-native';
import localJson from '../codelloy.local.json';

// codelloy.local.json is not in git. npm install makes it from codelloy.local.example.json.
const local: { key: string; baseUrl: string | null } = localJson;

if (local.key) {
  Codelloy.init({
    key: local.key,
    baseUrl: local.baseUrl ?? undefined,
    debug: true,
  });
}
const installId = local.key ? Codelloy.installId() : null;

type Arrival = Codelloy.CodelloyLink & { at: string };

export default function App() {
  const [links, setLinks] = useState<Arrival[]>([]);

  useEffect(
    () =>
      Codelloy.onLink((link) => {
        setLinks((old) => [
          { ...link, at: new Date().toLocaleTimeString() },
          ...old,
        ]);
      }),
    []
  );

  return (
    <ScrollView contentContainerStyle={styles.screen}>
      <Text style={styles.title}>Codelloy example</Text>
      <Text>
        {local.key
          ? `installId: ${installId ?? 'none'}`
          : 'Set the key in example/codelloy.local.json.'}
      </Text>
      {links.length === 0 && <Text>No link yet.</Text>}
      {links.map((link) => (
        <View key={link.id} style={styles.link}>
          <Text>{link.at}</Text>
          <Text>url: {link.url}</Text>
          <Text>shortUrl: {link.shortUrl}</Text>
          <Text>isDeferred: {String(link.isDeferred)}</Text>
          <Text>matchType: {link.matchType}</Text>
          <Text>confidence: {link.confidence}</Text>
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { padding: 24, paddingTop: 72, gap: 12 },
  title: { fontSize: 22, fontWeight: '600' },
  link: { padding: 12, borderRadius: 8, backgroundColor: '#eef2f7', gap: 2 },
});
