import { NextResponse } from "next/server";

export class HttpError extends Error {
  readonly status: number;
  readonly details?: unknown;

  constructor(status: number, message: string, details?: unknown) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

export function errorResponse(error: unknown) {
  if (error instanceof HttpError) {
    return NextResponse.json(
      {
        error: error.message,
        details: error.details ?? null
      },
      { status: error.status }
    );
  }

  console.error("Unhandled error", error);
  return NextResponse.json(
    {
      error: "服务器错误，请稍后再试"
    },
    { status: 500 }
  );
}
