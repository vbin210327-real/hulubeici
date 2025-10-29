export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      wordbooks: {
        Row: {
          id: string;
          owner_id: string | null;
          title: string;
          subtitle: string | null;
          target_passes: number;
          is_template: boolean;
          template_version: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          owner_id?: string | null;
          title: string;
          subtitle?: string | null;
          target_passes?: number;
          is_template?: boolean;
          template_version?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          owner_id?: string | null;
          title?: string;
          subtitle?: string | null;
          target_passes?: number;
          is_template?: boolean;
          template_version?: number;
          created_at?: string;
          updated_at?: string;
        };
      };
      word_entries: {
        Row: {
          id: string;
          wordbook_id: string;
          lemma: string;
          definition: string;
          ordinal: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          wordbook_id: string;
          lemma: string;
          definition: string;
          ordinal?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          wordbook_id?: string;
          lemma?: string;
          definition?: string;
          ordinal?: number;
          created_at?: string;
          updated_at?: string;
        };
      };
      section_progress: {
        Row: {
          user_id: string;
          wordbook_id: string;
          completed_pages: number;
          completed_passes: number;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          wordbook_id: string;
          completed_pages?: number;
          completed_passes?: number;
          updated_at?: string;
        };
        Update: {
          user_id?: string;
          wordbook_id?: string;
          completed_pages?: number;
          completed_passes?: number;
          updated_at?: string;
        };
      };
      daily_progress: {
        Row: {
          user_id: string;
          progress_date: string;
          words_learned: number;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          progress_date: string;
          words_learned?: number;
          updated_at?: string;
        };
        Update: {
          user_id?: string;
          progress_date?: string;
          words_learned?: number;
          updated_at?: string;
        };
      };
      word_visibility: {
        Row: {
          user_id: string;
          word_entry_id: string;
          show_word: boolean;
          show_meaning: boolean;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          word_entry_id: string;
          show_word?: boolean;
          show_meaning?: boolean;
          updated_at?: string;
        };
        Update: {
          user_id?: string;
          word_entry_id?: string;
          show_word?: boolean;
          show_meaning?: boolean;
          updated_at?: string;
        };
      };
      user_profiles: {
        Row: {
          user_id: string;
          display_name: string;
          avatar_emoji: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          display_name?: string;
          avatar_emoji?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          user_id?: string;
          display_name?: string;
          avatar_emoji?: string;
          created_at?: string;
          updated_at?: string;
        };
      };
    };
    Views: {};
    Functions: {};
    Enums: {};
    CompositeTypes: {};
  };
};
