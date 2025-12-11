import type { HostComponent, ViewProps } from 'react-native';
import { codegenNativeComponent } from 'react-native';
import type { CodegenTypes } from 'react-native';

export interface ThemeConfiguration {
  mode: string;
  color1: string;
  color2: string;
}

export interface ImageData {
  publicUrl?: string;
  originalFilename?: string;
}

export interface Message {
  uuid: string;
  text: string;
  isUser: boolean;
  readByCharacterAt?: CodegenTypes.Double;
  isTypingIndicator?: boolean;
  image?: ImageData;
  reaction?: string;
}

export interface NativeProps extends ViewProps {
  messages: Message[];
  theme: ThemeConfiguration;
  composerHeight: CodegenTypes.Double;
  onRequestDismissKeyboard?: CodegenTypes.DirectEventHandler<null>;
  onReply: CodegenTypes.DirectEventHandler<{ messageUuid: string }>;
  onCopy: CodegenTypes.DirectEventHandler<{ messageUuid: string }>;
  onReactionSelect: CodegenTypes.DirectEventHandler<{
    messageUuid: string;
    emoji: string;
  }>;
  onEmojiPickerOpen: CodegenTypes.DirectEventHandler<{ messageUuid: string }>;
  onContextMenuDismiss: CodegenTypes.DirectEventHandler<{
    shouldRefocusComposer: boolean;
  }>;
}

export default codegenNativeComponent<NativeProps>(
  'AurenChatView'
) as HostComponent<NativeProps>;
