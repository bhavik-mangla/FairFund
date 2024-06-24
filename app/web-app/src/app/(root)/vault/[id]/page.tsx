import TableWrapper from '@/components/proposal-table/table-wrapper';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import CardWrapper from '@/components/vault-details-card-wrapper';
import Link from 'next/link';
import prisma from '@/lib/db';
import { redirect } from 'next/navigation';
import DistributeFundsButton from '@/components/distrubute-funds-botton';
import { cn } from '@/lib/utils';

export default async function VaultDetailsPage({
    params,
}: {
    params: {
        id: string;
    };
}) {
    const id = params.id;
    const vault = await prisma.fundingVault.findUnique({
        where: {
            id: Number(id),
        },
    });
    if (!vault) {
        redirect('/dashboard');
    }

    return (
        <div className="p-8 w-full h-full flex justify-center items-center flex-col gap-4">
            <div className="space-y-2 w-full">
                <h3 className="text-lg font-medium">Vault Details</h3>
                <p className="text-sm text-muted-foreground">
                    View the details of the vault.
                </p>
            </div>
            <Separator className="bg-primary/10" />
            <CardWrapper fundingVault={vault} />
            <div className="space-y-2 w-full">
                <h3 className="text-lg font-medium">All Proposals</h3>
                <p className="text-sm text-muted-foreground">
                    All the proposals submitted to this vault.
                </p>
            </div>
            <Separator className="bg-primary/10" />
            <div className="w-full border-2 shadow-sm rounded-lg overflow-hidden min-h-96">
                <TableWrapper fundingVaultId={Number(id)} />
            </div>
            <div className="space-y-2 w-full">
                <h3 className="text-lg font-medium">Actions</h3>
            </div>
            <Separator className="bg-primary/10" />
            <div className="m-2 w-full flex flex-wrap gap-2">
                <Link
                    href={`/proposal/new?vaultId=${id}`}
                    className={cn(
                        'grow',
                        vault.tallyDate.getTime() < Date.now() &&
                            'pointer-events-none'
                    )}
                >
                    <Button
                        className="w-full"
                        disabled={vault.tallyDate.getTime() < Date.now()}
                    >
                        Create Proposal
                    </Button>
                </Link>
                <Link
                    href={`/vault/deposit?vaultId=${id}`}
                    className={cn(
                        'grow',
                        vault.tallyDate.getTime() < Date.now() &&
                            'pointer-events-none'
                    )}
                >
                    <Button
                        className="w-full"
                        disabled={vault.tallyDate.getTime() < Date.now()}
                    >
                        Deposit Funding Tokens
                    </Button>
                </Link>
                <Link
                    href={`/vault/register?vaultId=${id}`}
                    className={cn(
                        'grow',
                        vault.tallyDate.getTime() < Date.now() &&
                            'pointer-events-none'
                    )}
                >
                    <Button
                        className="w-full"
                        disabled={vault.tallyDate.getTime() < Date.now()}
                    >
                        Register to Vote
                    </Button>
                </Link>
                <DistributeFundsButton fundingVault={vault} className="grow" />
            </div>
        </div>
    );
}
