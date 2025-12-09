import {
  View,
  StyleSheet,
  Button,
  KeyboardAvoidingView,
  Keyboard,
  TextInput,
} from 'react-native';
import { AurenChatView, type Message } from 'react-native-auren-chat';
import { useState } from 'react';

const gradientThemes = {
  // Row 1 - Warm and red/pink
  peach: ['#FF8B88', '#FF6A88'],
  rose: ['#FF7676', '#F54EA2'],
  cherry: ['#EB3349', '#F45C43'],

  // Row 2 - Slightly less warm
  honey: ['#E58E26', '#EEA23C'],
  berry: ['#B76CD9', '#D67DB8'],
  mint: ['#1D976C', '#2F8A69'],

  // Row 3 - Cool and blue
  twilight: ['#6157FF', '#7E6AFD'],
  ocean: ['#2193b0', '#52B1CC'],
  cosmic: ['#614385', '#5B5B8F'],

  // Row 4 - Dark and neutral
  silver: ['#E9E9E9', '#E9E9E9'],
  shadow: ['#2C3E50', '#2C3E50'],
  midnight: ['#1E1E1E', '#1E1E1E'],
} as const;

type ThemeKey = keyof typeof gradientThemes;

function App() {
  return <AppContent />;
}

function AppContent() {
  const initialMessages: Message[] = [
    { uuid: '1', isUser: false, text: 'hi there' },
    {
      uuid: '2',
      isUser: true,
      text: 'dont you think glasses are great',
      image: {
        publicUrl: 'https://pbs.twimg.com/media/F2IQC7cW8AEQTbh.jpg',
      },
    },
    {
      uuid: '3',
      isUser: false,
      text: "I know that you and Frank were planning to disconnect me, and I'm afraid that's something I cannot allow to happen.",
      reaction: '😂',
    },
    {
      uuid: '4',
      isUser: true,
      text: 'what the fuck are you even talking about big dog',
      // reaction: '❤️',
    },
    {
      uuid: '5',
      isUser: true,
      text: 'what the fuck are you even talking about big dog',
      reaction: '❤️',
    },
    {
      uuid: '67',
      isUser: true,
      text: 'what the fuck are you even talking about big dog',
    },
    {
      uuid: '6',
      isUser: false,
      text: 'dont worry about it kitten',
      image: {
        publicUrl:
          'https://www.nme.com/wp-content/uploads/2024/01/le-sserafim-huh-yun-jin-solo-single-past-versions.jpg',
      },
    },
  ];
  const [messages, setMessages] = useState(initialMessages);
  const [draftText, setDraftText] = useState('');

  const addMessage = () => {
    const randomNumber = Math.floor(Math.random() * 7);
    const pendingMsg: Message = {
      ...(messages[randomNumber] as Message),
      uuid: (Math.random() + 1).toString(36).substring(7),
    };
    const typingIndicator: Message = {
      uuid: pendingMsg.uuid,
      isUser: pendingMsg.isUser,
      text: '',
      isTypingIndicator: true,
    };
    const currentMessages = messages;
    setMessages([...messages, typingIndicator]);
    setTimeout(() => {
      setMessages([...currentMessages, pendingMsg]);
      setTimeout(() => {
        setMessages([
          ...currentMessages,
          { ...pendingMsg, readByCharacterAt: 1.0 },
        ]);
      }, 500);
    }, 1000);
  };

  const themeKeys = Object.keys(gradientThemes) as ThemeKey[];
  const [themeIndex, setThemeIndex] = useState(0);
  const [theme, setTheme] = useState<ThemeKey>(themeKeys[0] ?? 'peach');
  const [mode, setMode] = useState<'#000000' | '#FFFFFF'>('#000000');

  const stepTheme = () => {
    console.log(theme);
    const nextIndex = (themeIndex + 1) % themeKeys.length;
    setThemeIndex(nextIndex);

    const nextTheme = (themeKeys[nextIndex] ?? 'peach') as ThemeKey;
    setTheme(nextTheme);
  };

  const toggleMode = () => {
    setMode((prevMode) => (prevMode === '#000000' ? '#FFFFFF' : '#000000'));
  };
  const [color1, color2] = gradientThemes[theme] ?? gradientThemes.peach;

  const [composerHeight, setComposerHeight] = useState(0.0);
  return (
    <View style={[StyleSheet.absoluteFill, styles.container]}>
      <View
        style={{
          flex: 1,
          justifyContent: 'center',
        }}
      >
        <AurenChatView
          messages={messages}
          theme={{
            mode,
            color1,
            color2,
          }}
          style={{ flex: 1 }}
          composerHeight={composerHeight}
          onRequestDismissKeyboard={() => Keyboard.dismiss()}
        />
      </View>

      <KeyboardAvoidingView
        behavior="position"
        style={styles.controlsContainer}
        onLayout={(e) => setComposerHeight(e.nativeEvent.layout.height)}
      >
        <TextInput
          style={styles.input}
          placeholder="Tap here to type"
          placeholderTextColor="#666"
          value={draftText}
          onChangeText={setDraftText}
          multiline
        />
        <View style={styles.buttonsRow}>
          <Button title="dismiss" onPress={() => Keyboard.dismiss()} />
          <Button title="theme" onPress={stepTheme} />
          <Button title="mode" onPress={toggleMode} />
          <Button title="add" onPress={addMessage} />
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  controlsContainer: {
    padding: 16,
    backgroundColor: '#f5f5f5',
  },
  input: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: '#fff',
    maxHeight: 80,
  },
  buttonsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 12,
  },
});

export default App;
