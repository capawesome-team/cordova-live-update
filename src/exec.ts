/// <reference types="cordova" />

const SERVICE_NAME = 'LiveUpdate';

export function exec<T = void>(
  action: string,
  args: unknown[] = [],
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    cordova.exec(
      (result: T) => resolve(result),
      (error: unknown) => reject(error),
      SERVICE_NAME,
      action,
      args,
    );
  });
}
