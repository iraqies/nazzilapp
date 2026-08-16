import * as MediaLibrary from 'expo-media-library';

export async function saveToGallery(localUri: string): Promise<void> {
  const perm = await MediaLibrary.requestPermissionsAsync();
  if (!perm.granted) throw new Error('permission');
  await MediaLibrary.createAssetAsync(localUri);
}
